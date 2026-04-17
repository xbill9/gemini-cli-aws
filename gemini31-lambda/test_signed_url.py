import sys
import os
import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

def sign_and_request(url, method='GET', payload=None):
    session = boto3.Session()
    credentials = session.get_credentials()
    region = 'us-east-1'
    service = 'lambda'
    
    auth = SigV4Auth(credentials, service, region)
    
    headers = {'Host': url.split('//')[1].split('/')[0]}
    request = AWSRequest(method=method, url=url, data=payload, headers=headers)
    auth.add_auth(request)
    
    prepared = request.prepare()
    response = requests.request(
        method=prepared.method,
        url=prepared.url,
        headers=prepared.headers,
        data=prepared.body
    )
    return response

if __name__ == "__main__":
    url = sys.argv[1]
    response = sign_and_request(url)
    print(f"Status: {response.status_code}")
    print(f"Body: {response.text}")
