import boto3, os, urllib.parse

s3 = boto3.client("s3")
PROCESSED = os.environ["PROCESSED_BUCKET"]

def lambda_handler(event, context):
    for record in event["Records"]:
        src_bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        obj = s3.get_object(Bucket=src_bucket, Key=key)
        size = obj["ContentLength"]
        # Example "processing": write a tiny summary file to the processed bucket
        summary = f"file={key} bytes={size}\n"
        s3.put_object(Bucket=PROCESSED, Key=f"{key}.summary.txt", Body=summary.encode())
    return {"processed": len(event["Records"])}