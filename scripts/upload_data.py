#!/usr/bin/env python3
"""Upload files from a local data directory to S3.

Usage:
  python scripts/upload_data.py --bucket my-bucket --source data/ine --prefix raw/

It reads files recursively from `--source` and uploads them preserving relative paths.
"""
import argparse
import os
import sys
import logging
from pathlib import Path

try:
    import boto3
    from botocore.exceptions import ClientError
except Exception:
    print("Missing dependency 'boto3'. Install with: pip install -r scripts/requirements.txt")
    sys.exit(1)


def upload_directory(s3_client, bucket: str, source_dir: Path, prefix: str = ""):
    source_dir = source_dir.expanduser().resolve()
    if not source_dir.exists():
        raise SystemExit(f"Source directory not found: {source_dir}")

    uploaded = []
    for root, _, files in os.walk(source_dir):
        for fname in files:
            local_path = Path(root) / fname
            relative_path = local_path.relative_to(source_dir)
            s3_key = (prefix.rstrip('/') + '/' if prefix and not prefix.endswith('/') else prefix) + str(relative_path).replace('\\\\', '/')
            try:
                s3_client.upload_file(str(local_path), bucket, s3_key)
                logging.info(f"Uploaded {local_path} -> s3://{bucket}/{s3_key}")
                uploaded.append((local_path, s3_key))
            except ClientError as e:
                logging.error(f"Failed to upload {local_path}: {e}")
    return uploaded


def main():
    parser = argparse.ArgumentParser(description="Upload local data directory to S3")
    parser.add_argument("--bucket", required=True, help="S3 bucket name")
    parser.add_argument("--source", default="data/ine", help="Local source directory to upload")
    parser.add_argument("--prefix", default="raw/", help="S3 key prefix")
    parser.add_argument("--region", default=None, help="AWS region (optional)")
    parser.add_argument("--profile", default=None, help="AWS CLI profile to use (optional)")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    session_kwargs = {}
    if args.profile:
        session_kwargs["profile_name"] = args.profile
    if args.region:
        session_kwargs["region_name"] = args.region

    session = boto3.Session(**session_kwargs) if session_kwargs else boto3.Session()
    s3 = session.client('s3')

    source_dir = Path(args.source)
    uploaded = upload_directory(s3, args.bucket, source_dir, args.prefix)

    print(f"Uploaded {len(uploaded)} files to s3://{args.bucket}/{args.prefix}")


if __name__ == '__main__':
    main()
