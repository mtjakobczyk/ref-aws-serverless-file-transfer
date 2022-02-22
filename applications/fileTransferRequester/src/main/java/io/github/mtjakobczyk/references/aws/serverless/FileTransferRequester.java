package io.github.mtjakobczyk.references.aws.serverless;

import static java.util.Map.entry;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.Map.Entry;
import java.util.UUID;

import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import com.amazonaws.services.dynamodbv2.document.DynamoDB;
import com.amazonaws.services.dynamodbv2.document.Item;
import com.amazonaws.services.dynamodbv2.document.Table;
import com.amazonaws.services.dynamodbv2.document.spec.UpdateItemSpec;
import com.amazonaws.services.dynamodbv2.document.utils.ValueMap;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.S3Event;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

public class FileTransferRequester implements RequestHandler<S3Event, String>{
  private enum RecordFileTransferEventType { PUT, UPDATE };
  private Gson gson = new GsonBuilder().setPrettyPrinting().create();
  private Table fileTransfersTable;
  private LambdaLogger logger;
  private String fileProcessingId;
  @Override
  public String handleRequest(S3Event event, Context context) {
    try {
      initializeFields(event, context);

      var s3Event = event.getRecords().get(0).getS3();
  
      recordFileTransferEvent(
        RecordFileTransferEventType.PUT,
        fileProcessingId, 
        Map.ofEntries(
          entry("startOfProcessing", LocalDateTime.now().toString()), // ISO-8601 Format
          entry("filename", s3Event.getObject().getUrlDecodedKey()),
          entry("fileSizeBytes", s3Event.getObject().getSizeAsLong()),
          entry("fileVersion", s3Event.getObject().getVersionId())
        )
      );

      // TODO Read File and Call API Gateway

      var fileTransferId = UUID.randomUUID().toString();

      recordFileTransferEvent(
        RecordFileTransferEventType.UPDATE,
        fileProcessingId, 
        Map.ofEntries(
          entry("endOfProcessing", LocalDateTime.now().toString()), // ISO-8601 Format
          entry("fileTransferId", fileTransferId)
        )
      );

    } catch(Exception ex) {
      logger.log("ERROR " + fileProcessingId + " " + ex.getMessage());
      return "500 Internal Server Error";
    }
    return "200 OK";
  }

  private void initializeFields(S3Event event, Context context) {
    logger = context.getLogger();
    fileProcessingId = context.getAwsRequestId();
    logger.log("EVENT " + fileProcessingId + " " + gson.toJson(event));
    
    var fileTransfersTableName = getEnvironmentVariable("FILE_TRANSFERS_TABLE");
    if(fileTransfersTableName == null || fileTransfersTableName.isEmpty()) {
      throw new IllegalArgumentException("FILE_TRANSFERS_TABLE environment variables is not set");
    }
    
    var client = AmazonDynamoDBClientBuilder.standard().build();
    DynamoDB dynamoDB = new DynamoDB(client);
    fileTransfersTable = dynamoDB.getTable(fileTransfersTableName);
  }

  private void recordFileTransferEvent(RecordFileTransferEventType type, String fileProcessingId, Map<String, Object> attributes) {
    if(attributes == null || attributes.isEmpty()) {
      throw new IllegalArgumentException("There are no attributes passed to the recordFileTransferEvent");
    }
    switch(type) {
      case PUT:
        var item = Item.fromMap(attributes).withPrimaryKey("fileProcessingId", fileProcessingId);
        logger.log("PUTITEM " + fileProcessingId + " " + item.toJSONPretty());
        fileTransfersTable.putItem(item);
        break;
      case UPDATE:
        StringBuilder updateExpressionBuilder = new StringBuilder("SET ");
        var valueMapForUpdate = new ValueMap();
        int i = 1;
        for(Entry<String, Object> entry : attributes.entrySet()) {
          String valueMapKey = ":v"+i++;
          updateExpressionBuilder.append(entry.getKey()).append(" = ").append(valueMapKey).append(",");
          valueMapForUpdate = valueMapForUpdate.withString(valueMapKey, entry.getValue().toString());
        }
        updateExpressionBuilder.deleteCharAt(updateExpressionBuilder.length()-1);
        String updateExpression = updateExpressionBuilder.toString();
        var updateItemSpec = new UpdateItemSpec().withPrimaryKey("fileProcessingId", fileProcessingId)
                                    .withUpdateExpression(updateExpression).withValueMap(valueMapForUpdate);
                                          
        logger.log("UPDATEITEM " + fileProcessingId);
        fileTransfersTable.updateItem(updateItemSpec);
        break;
    }
  }

  protected String getEnvironmentVariable(String name) {
    return System.getenv(name);
  }
}