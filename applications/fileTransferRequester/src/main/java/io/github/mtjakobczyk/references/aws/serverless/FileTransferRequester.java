package io.github.mtjakobczyk.references.aws.serverless;

import java.util.Map;
import static java.util.Map.entry;

import java.time.LocalTime;

import com.amazonaws.services.dynamodbv2.AmazonDynamoDBClientBuilder;
import com.amazonaws.services.dynamodbv2.document.DynamoDB;
import com.amazonaws.services.dynamodbv2.document.Item;
import com.amazonaws.services.dynamodbv2.document.Table;
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
  String fileProcessingId;
  @Override
  public String handleRequest(S3Event event, Context context) {
    try {
      initializeFields(event, context);

      var s3Event = event.getRecords().get(0).getS3();
  
      recordFileTransferEvent(
        RecordFileTransferEventType.PUT,
        fileProcessingId, 
        Map.ofEntries(
          entry("startOfProcessing", LocalTime.now().toString()), // ISO-8601 Format
          entry("filename", s3Event.getObject().getUrlDecodedKey()),
          entry("fileSizeBytes", s3Event.getObject().getSizeAsLong()),
          entry("fileVersion", s3Event.getObject().getVersionId())
        )
      );


      // recordFileTransferEvent(
      //   RecordFileTransferEventType.UPDATE,
      //   fileProcessingId, 
      //   Map.ofEntries(
      //     entry("endOfProcessing", LocalTime.now().toString()), // ISO-8601 Format
      //     entry("fileTransferId", null)
      //   )
      // );

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
    
    var fileTransfersTableName = System.getenv("FILE_TRANSFERS_TABLE");
    if(fileTransfersTableName == null || fileTransfersTableName.isEmpty()) {
      throw new IllegalArgumentException("FILE_TRANSFERS_TABLE environment variables is not set");
    }
    
    var client = AmazonDynamoDBClientBuilder.standard().build();
    DynamoDB dynamoDB = new DynamoDB(client);
    fileTransfersTable = dynamoDB.getTable(fileTransfersTableName);
  }

  private void recordFileTransferEvent(RecordFileTransferEventType type, String fileProcessingId, Map<String, Object> attributes) {
    Item item = Item.fromMap(attributes).withPrimaryKey("fileProcessingId", fileProcessingId);
    logger.log("ITEM " + fileProcessingId + " " + item.toJSONPretty());
    switch(type) {
      case PUT:
        fileTransfersTable.putItem(item);
        break;
      case UPDATE:
        //fileTransfersTable.updateItem()
        break;
    }
    
  }
}