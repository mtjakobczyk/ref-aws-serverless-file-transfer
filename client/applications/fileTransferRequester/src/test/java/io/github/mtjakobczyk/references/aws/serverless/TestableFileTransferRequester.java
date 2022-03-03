package io.github.mtjakobczyk.references.aws.serverless;

import java.util.HashMap;
import java.util.Map;

public class TestableFileTransferRequester extends FileTransferRequester {
  private Map<String, String> mockedEnvironmentVariables = new HashMap<>();
  public TestableFileTransferRequester(Map<String, String> mockedEnvironmentVariables) {
    super();
    this.mockedEnvironmentVariables = mockedEnvironmentVariables;
  }

  protected String getEnvironmentVariable(String name) {
    return mockedEnvironmentVariables.get(name);
  }
}
