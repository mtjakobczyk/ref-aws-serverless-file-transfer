package io.github.mtjakobczyk.references.aws.serverless;
import static java.util.Map.entry;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.when;

import java.util.Map;
import java.util.UUID;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.events.S3Event;
import com.amazonaws.services.lambda.runtime.tests.annotations.Event;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
public class FileTransferRequesterTests {
  private UUID mockedRequestId = UUID.randomUUID();
  FileTransferRequester handler;
  @Mock
  Context context;
  @Mock
  LambdaLogger loggerMock;

  @BeforeEach
  public void setUp() throws Exception {
    handler = new TestableFileTransferRequester(Map.ofEntries(
        entry("FILE_TRANSFERS_TABLE", "bvz53ccr-clientOne-requested-file-transfers")
    ));
    when(context.getLogger()).thenReturn(loggerMock);       
    doAnswer(call -> {
          System.out.println((String)call.getArgument(0));//print to the console
          return null;
      }).when(loggerMock).log(anyString());
    
    when(context.getAwsRequestId()).thenReturn(mockedRequestId.toString());
  }
  @ParameterizedTest
  @Event(value = "event.json", type = S3Event.class)
  public void testInjectS3Event(S3Event event) {
    assertEquals("200 OK", handler.handleRequest(event, context));
  }
}
