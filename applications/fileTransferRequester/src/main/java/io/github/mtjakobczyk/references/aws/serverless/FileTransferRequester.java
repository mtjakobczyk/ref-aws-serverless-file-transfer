package io.github.mtjakobczyk.references.aws.serverless;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.S3Event;
import com.amazonaws.services.lambda.runtime.events.models.s3.S3EventNotification.S3EventNotificationRecord;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

public class FileTransferRequester implements RequestHandler<S3Event, String>{
  private Gson gson = new GsonBuilder().setPrettyPrinting().create();
  @Override
  public String handleRequest(S3Event event, Context context) {
    LambdaLogger logger = context.getLogger();
    logger.log("EVENT: " + gson.toJson(event));
    String response = "200 OK";
    try {
      S3EventNotificationRecord record = event.getRecords().get(0);
    
      var sourceEventS3Bucket = record.getS3().getBucket().getName();
      var sourceEventS3Key = record.getS3().getObject().getUrlDecodedKey();
      var objectSizeInBytes = record.getS3().getObject().getSizeAsLong();
  
      logger.log("BUCKET: " + sourceEventS3Bucket);
      logger.log("KEY: " + sourceEventS3Key);
      logger.log("SIZE: " + objectSizeInBytes + " bytes");
    } catch(Exception ex) {
      logger.log("ERROR " + ex.getMessage());
      response = "500 Internal Server Error";
    }
    return response;
  }
}