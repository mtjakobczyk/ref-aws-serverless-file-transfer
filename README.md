# Reference application (AWS) - transferring files over private REST API using serverless functions
This is a minimalistic application used to demonstrate an AWS-based implementation of a serverless function calling a private REST API hosted on AWS API Gateway using fine-grained authorisation.

## Architecture
![Architecture](./docs/architecture.svg)

When a new file is uploaded to the `in/` folder in the `Staging` Bucket, the **File Transfer Requester** Lambda function gets triggered.

In this way, for each new file, the **File Transfer Requester** Lambda function performs these steps:
1. Generate **File Processing UUID**
1. **Step 1.1** Creates a new Item in DynamoDB Table: 
    - Set the **File Processing UUID** as the item's primary key (`fileProcessingId`)
    - Set the following attributes: 
        - Start of Processing Timestamp (`startOfProcessing`)
        - Filename (`filename`)
        - File Size in Bytes (`fileSizeBytes`)
        - (optionally) File Version (`fileVersion`)
1. **Step 1.2** Read file contents
1. **Step 1.3** Upload the file (HTTP POST) to the file service
    - The service immediately returns a **File Transfer UUID**
1. **Step 1.4** Move file to the `accepted/` folder
    - Use `CopyObject` and `DeleteObject` AWS S3 APIs
1. **Step 1.5** Update the Item in DynamoDB Table: 
    - Use the **File Processing UUID** as the item's primary key (`fileProcessingId`)
    - Add the following attributes: 
        - **File Transfer UUID** (`fileTransferId`)
        - End of Processing Timestamp (`endOfProcessing`)

If at any stage the file processing fails, the file is moved to the `rejected` folder

## Security by Design
![Architecture](./docs/architecture-with-security.svg)


## Deployment
### 1. Service side
First, deploy only the file transfer service (`-target=module.file_service`).
```bash
../scripts/sts-teraform.sh apply -target=module.file_service
```
The list of registered clients is initially empty (because part of it is commented out):
```yaml
# part of infrastructure/file_service.tf
locals {
  registered_clients = [
    # {
    #   client_partition = "one"
    #   vpc_endpoint = module.client_one.client_vpc_endpoints
    # }
  ]
}
```
Because the list is initially empty, the "default deny all" IAM Resource Policy (`data.aws_iam_policy_document.default_deny_all.json`) gets attached to the REST API on API Gateway. See `aws_api_gateway_rest_api_policy.file_ingestion.policy`. This is fine at this stage. :)


### 2. Client side (a sample client)
#### 2.1 A sample client
Now, let's deploy the components (cloud infrastructure and Lambda) of a sample client system:
```bash
../scripts/sts-teraform.sh apply
```
1. The Lambda is **triggered** by each newly created file added to the `in/` folder inside the `...-clientOne-staging` bucket
1. The Lambda is configured to HTTP POST this file as binary payload to a REST API on API Gateway
      - The REST resource path: `/clients/{clientPartition}/orders/{orderIdentifier}`
      - The value `one` is used as `{clientPartition}` (See `CLIENT_PARTITION` environment variable set for Lambda)
      - The filename is set as `{orderIdentifier}`

As soon as the Terraform run completes, you can perform a first test, which will... fail, because the client has not been registered in the service yet.

#### 2.2 Smoke Test (failing)
- Just put some image file to the `in/` folder of the `...-clientOne-staging` bucket and wait a bit.
- After a few seconds, the file should be moved to the `rejected/` folder in the same bucket

If you look into CloudWatch, you will see entries saying:
> STATUS 403
>
> STATUS TEXT Forbidden 
>
> BODY User: anonymous is not authorized to perform: execute-api:Invoke on resource (...)/v1/POST/clients/one/orders/(...) **with explicit deny**

#### 2.3 Registering a new client
In the `infrastructure/file_service.tf` **uncomment** the entry for the newly added client (in the `local.registered client` list):
```yaml
locals {
  registered_clients = [
    {
      client_partition = "one"
      vpc_endpoint = module.client_one.client_vpc_endpoints
    }
  ]
}
```

Now, just apply changes.
```bash
../scripts/sts-teraform.sh apply
```
#### 2.4 Test 1 (succeeding)
- Put some other or the same image file to the `in/` folder of the `...-clientOne-staging` bucket and wait a bit.
- After a few seconds, the file should be moved to the `accepted/` folder in the same bucket
- Furthermore, you should a copy of the same file in the `one/*/` subfolder of the `...-file-ingestion` bucket. The API Gateway placed there the copy.

This time, if you look into CloudWatch, you will see entries saying:
> STATUS 202
>
> STATUS TEXT Accepted 

#### 2.5 Test 2 (failing)
In the `infrastructure/client_system_one.tf` file, change the `client_partition` to `two`:
```yml
#### Client One Parameters
locals {
  client_one = {
# ...
    client_partition = "two"
# ...
  }
}
```
Apply changes:
```bash
../scripts/sts-teraform.sh apply
```

- Put some other or the same image file to the `in/` folder of the `...-clientOne-staging` bucket and wait a bit.
- After a few seconds, the file should be moved to the `rejected/` folder in the same bucket
- You will *not* find any copy of the file in the `two/*/` subfolder of the `...-file-ingestion` bucket

Furthermore, if you look into CloudWatch, you will see entries saying:
> STATUS 403
>
> STATUS TEXT Forbidden 
>
> BODY User: anonymous is not authorized to perform: execute-api:Invoke on resource (...)/v1/POST/clients/**two**/orders/(...)

#### Postscriptum
If you need to let other clients use their dedicated paths (`/clients/three/*` or `/clients/pizza/*`), you just add the relevant object to the list (as shown below) and apply Terraform changes (which will amend the IAM resource policy and allow the VPC Endpoint access the private endpoint of API Gateway):
```yaml
locals {
  registered_clients = [
    {
      client_partition = "one"
      vpc_endpoint = "vpce-123456-efg"
    },
    {
      client_partition = "three"
      vpc_endpoint = "vpce-789012-ihk"
    },
    {
      client_partition = "pizza"
      vpc_endpoint = "vpce-556677-zxc"
    }
  ]
}
```