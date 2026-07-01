import boto3, json, os, psycopg

def _creds():
    sm = boto3.client("secretsmanager")
    secret = sm.get_secret_value(SecretId=os.environ["DB_SECRET_ARN"])
    return json.loads(secret["SecretString"])  # {"username":..., "password":...}

def get_conn():
    c = _creds()
    return psycopg.connect(
        host=os.environ["DB_HOST"], dbname=os.environ.get("DB_NAME", "portfolio"),
        user=c["username"], password=c["password"], port=5432,
    )