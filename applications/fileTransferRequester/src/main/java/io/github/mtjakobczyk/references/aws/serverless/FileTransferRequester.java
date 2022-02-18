package io.github.mtjakobczyk.references.aws.serverless;
import java.util.Map;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

public class FileTransferRequester implements RequestHandler<Map<String,String>, String>{
  @Override
  public String handleRequest(Map<String, String> input, Context context) {
    String response = "200 OK";
    return response;
  }
}