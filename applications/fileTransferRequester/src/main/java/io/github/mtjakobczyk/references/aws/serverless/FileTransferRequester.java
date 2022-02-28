package io.github.mtjakobczyk.references.aws.serverless;

import static java.util.Map.entry;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.Map.Entry;

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
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.model.S3Object;
import com.amazonaws.services.s3.model.S3ObjectInputStream;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import kong.unirest.Unirest;

public class FileTransferRequester implements RequestHandler<S3Event, String>{
  private enum RecordFileTransferEventType { PUT, UPDATE };
  private Gson gson = new GsonBuilder().setPrettyPrinting().create();
  private Table fileTransfersTable;
  private AmazonS3 s3;
  private LambdaLogger logger;
  private String fileProcessingId;
  private String apiEndpoint;
  private String apiBasepath;
  private String apiVPCEEndpoint;
  private String clientPartition;
  private String s3FolderAccepted;
  private String s3FolderRejected;
  @Override
  public String handleRequest(S3Event event, Context context) {
    try {
      initializeFields(event, context);

      var s3Event = event.getRecords().get(0).getS3();
      String bucketName = s3Event.getBucket().getName();
      String objectKey = s3Event.getObject().getUrlDecodedKey();
      String objectFilename = objectKey.replaceFirst("^in/", "");

      recordFileTransferEvent(
        RecordFileTransferEventType.PUT,
        fileProcessingId, 
        Map.ofEntries(
          entry("startOfProcessing", LocalDateTime.now().toString()), // ISO-8601 Format
          entry("filename", objectKey),
          entry("fileSizeBytes", s3Event.getObject().getSizeAsLong()),
          entry("fileVersion", s3Event.getObject().getVersionId())
        )
      );

      S3Object o = s3.getObject(bucketName, objectKey);
      var oContentType = o.getObjectMetadata().getContentType();
      S3ObjectInputStream s3is = o.getObjectContent();

      String url = "https://"+apiVPCEEndpoint+"/"+apiBasepath+"/clients/"+clientPartition+"/orders/"+objectFilename;
      logger.log("DEBUG " + fileProcessingId + " URL " + url);
      logger.log("DEBUG " + fileProcessingId + " Host Header " + apiEndpoint);
  
      var res = Unirest.post(url)
       .header("Content-Type", oContentType)
       .header("Host", apiEndpoint)
       .body(s3is)
       .asString();
      
      logger.log("DEBUG " + fileProcessingId + " STATUS " + res.getStatus());
      logger.log("DEBUG " + fileProcessingId + " STATUS TEXT " + res.getStatusText());
      logger.log("DEBUG " + fileProcessingId + " BODY " + res.getBody());

      s3is.close();

      getAmazonS3().copyObject(bucketName, objectKey, bucketName, ((res.getStatus()==202) ? s3FolderAccepted : s3FolderRejected ) +"/"+objectFilename);
      getAmazonS3().deleteObject(bucketName, objectKey);

      recordFileTransferEvent(
        RecordFileTransferEventType.UPDATE,
        fileProcessingId, 
        Map.ofEntries(
          entry("endOfProcessing", LocalDateTime.now().toString()), // ISO-8601 Format
          entry("fileTransferId", "")
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
    
    // Environment Variables
    clientPartition = getEnvironmentVariable("CLIENT_PARTITION");
    s3FolderAccepted = getEnvironmentVariable("S3_FOLDER_ACCEPTED");
    s3FolderRejected = getEnvironmentVariable("S3_FOLDER_REJECTED");
    apiEndpoint = getEnvironmentVariable("FILE_TRANSFER_API_INVOKE_URL");
    apiBasepath = getEnvironmentVariable("FILE_TRANSFER_API_BASEPATH");
    apiVPCEEndpoint = getEnvironmentVariable("FILE_TRANSFER_API_VPCE_HOSTNAME");
    logger.log("DEBUG " + fileProcessingId + " API " + apiEndpoint);
    var fileTransfersTableName = getEnvironmentVariable("FILE_TRANSFERS_TABLE");

    // AWS DynamoDB
    var client = AmazonDynamoDBClientBuilder.standard().build();
    DynamoDB dynamoDB = new DynamoDB(client);
    fileTransfersTable = dynamoDB.getTable(fileTransfersTableName);

    // AWS S3
    s3 = AmazonS3ClientBuilder.standard().build();
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
    var ev = System.getenv(name);
    if(ev == null || ev.isEmpty()) {
      throw new IllegalArgumentException(name+" environment variables is not set");
    }
    return ev;
  }
  protected AmazonS3 getAmazonS3() {
    return this.s3;
  }

}