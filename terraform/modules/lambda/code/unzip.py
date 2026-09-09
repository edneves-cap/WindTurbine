# https://medium.com/@darrenroback/how-to-process-and-extract-zip-files-with-aws-lambda-ed2a59f6b746
# This might work for files under 1GB, as is the case. Anyway lambda has 1GB limitaiton and 15 minutes timeout so Step Functions + EC2 might be needed: https://aws.amazon.com/blogs/storage/automatically-decompress-files-in-amazon-s3-using-aws-step-functions/
# Other solution might be Glue: https://stackoverflow.com/questions/32697790/unzip-a-large-zip-file-on-amazon-s3 (might be direct for dataset population)
# Import statements
import boto3
import zipfile 
from datetime import * 
import os
import logging
import sys
import traceback
import json

# Set logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Create boto3 session
session = boto3.Session()

# Create S3 client object
s3_client = session.client('s3') 

# Create S3 resource
s3_resource = boto3.resource('s3')

# Set temp file path
tmp_file_path = '/tmp/file.zip'

# Set unzipped output path
unzip_path = 'unzipped/'

# Download file function
def download_file(bucket, key):
    
    # Create S3 resource object
    s3_object = s3_resource.Object(bucket, key)

    # Download file to /tmp
    try:
        logger.info("Downloading file to /tmp...")
        s3_object.download_file(tmp_file_path)
        logger.info("Download complete.")
    except Exception as e:
        exception_type, exception_value, exception_traceback = sys.exc_info()
        traceback_string = traceback.format_exception(exception_type, exception_value, exception_traceback)
        err_msg = json.dumps({
            "errorType": exception_type.__name__,
            "errorMessage": str(exception_value),
            "stackTrace": traceback_string
        })
        logger.error(err_msg)
        
    # List zipped contents of /tmp
    logger.info("Zipped contents of /tmp directory:")
    for file in os.listdir("/tmp"):
        logger.info(os.path.join(f"/tmp{file}"))

# Unzip file function
def unzip_file(bucket, key): 
    # Create zipfile object
    zip = zipfile.ZipFile(tmp_file_path)

    # Extract only shapefile components and tiff files to /tmp
    logger.info("Extracting only .shp/.shx/.dbf/.prj/.cpg and .tif/.tiff files to /tmp...")

    # base name to use for extracted files
    zip_basename = os.path.splitext(os.path.basename(key))[0]

    tif_count = 0

    # List contents of /tmp
    logger.info("Extracted contents of /tmp directory:")
    for file in os.listdir("/tmp"):
        logger.info(os.path.join(f"/tmp{file}"))
        logger.info(f"File size: {os.path.getsize(os.path.join('/tmp', file))} bytes")

    # Process each file within the zip: filter and extract
    #shp_components = set(['.shp', '.shx', '.dbf', '.prj', '.cpg'])
    #tif_exts = set(['.tif', '.tiff'])

    shp_components = set(['.shp'])
    tif_exts = set(['.tif'])

    # collect shapefile members to rename consistently
    shapefile_members = []

    for member in zip.namelist():
        base = os.path.basename(member)
        _, ext = os.path.splitext(base)
        ext = ext.lower()
        if ext in shp_components:
            shapefile_members.append(member)
        elif ext in tif_exts:
            # extract this tiff and rename to zip_basename or indexed name
            tif_count += 1
            target_name = f"{zip_basename}.tif" if tif_count == 1 else f"{zip_basename}_{tif_count}.tif"
            target_path = os.path.join('/tmp', target_name)
            logger.info(f"Extracting TIFF {member} to {target_path}")
            with zip.open(member) as src, open(target_path, 'wb') as dst:
                dst.write(src.read())
            # upload to s3
            logger.info(f"Uploading file {target_name} to {bucket}/{unzip_path}{target_name}")
            try:
                with open(target_path, 'rb') as f:
                    s3_client.upload_fileobj(Fileobj=f, Bucket=bucket, Key=f'{unzip_path}{target_name}')
            except Exception as e:
                exception_type, exception_value, exception_traceback = sys.exc_info()
                traceback_string = traceback.format_exception(exception_type, exception_value, exception_traceback)
                err_msg = json.dumps({
                    "errorType": exception_type.__name__,
                    "errorMessage": str(exception_value),
                    "stackTrace": traceback_string
                })
                logger.error(err_msg)
            # remove local file
            try:
                os.remove(target_path)
            except OSError:
                pass

    # If any shapefile components found, extract and rename them to a consistent basename
    if shapefile_members:
        logger.info(f"Found shapefile components: {shapefile_members}")
        # group by original base name; if multiple different shapefiles present, warn
        original_bases = set([os.path.splitext(os.path.basename(m))[0] for m in shapefile_members])
        if len(original_bases) > 1:
            logger.warning("Multiple shapefile base names found in zip; components will be merged under a single basename")
        # extract each component and rename to zip_basename with same extension
        for member in shapefile_members:
            base = os.path.basename(member)
            _, ext = os.path.splitext(base)
            ext = ext.lower()
            target_name = f"{zip_basename}{ext}"
            target_path = os.path.join('/tmp', target_name)
            logger.info(f"Extracting shapefile component {member} to {target_path}")
            with zip.open(member) as src, open(target_path, 'wb') as dst:
                dst.write(src.read())
            # upload
            logger.info(f"Uploading file {target_name} to {bucket}/{unzip_path}{target_name}")
            try:
                with open(target_path, 'rb') as f:
                    s3_client.upload_fileobj(Fileobj=f, Bucket=bucket, Key=f'{unzip_path}{target_name}')
            except Exception as e:
                exception_type, exception_value, exception_traceback = sys.exc_info()
                traceback_string = traceback.format_exception(exception_type, exception_value, exception_traceback)
                err_msg = json.dumps({
                    "errorType": exception_type.__name__,
                    "errorMessage": str(exception_value),
                    "stackTrace": traceback_string
                })
                logger.error(err_msg)
            # remove local file
            try:
                os.remove(target_path)
            except OSError:
                pass

    # Delete the zip file from /tmp
    logger.info("Deleting zip file from /tmp...")
    try:
        os.remove(tmp_file_path)
    except OSError:
        pass

# Main Lambda function
def lambda_handler(event, context):

  # Process each object in the S3 event 
  for record in event['Records']:

    # Extract bucket and key
    bucket = record['s3']['bucket']['name'] 
    key = record['s3']['object']['key']

    # Logging
    logger.info(f"Received bucket: {bucket}")
    logger.info(f"Received key: {key}")

    # Call functions to download and unzip file
    try:
      download_file(bucket, key)  
      unzip_file(bucket, key)
    except Exception as e:
        exception_type, exception_value, exception_traceback = sys.exc_info()
        traceback_string = traceback.format_exception(exception_type, exception_value, exception_traceback)
        err_msg = json.dumps({
            "errorType": exception_type.__name__,
            "errorMessage": str(exception_value),
            "stackTrace": traceback_string
        })
        logger.error(err_msg)