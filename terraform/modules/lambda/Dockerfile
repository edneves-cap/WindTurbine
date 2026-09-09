FROM public.ecr.aws/lambda/python:3.11

# GDAL is installed inside the image, so Lambda no longer needs EFS.
RUN dnf install -y gdal gdal-libs \
    && dnf clean all \
    && rm -rf /var/cache/dnf

COPY code/ ${LAMBDA_TASK_ROOT}/

CMD ["unzip.lambda_handler"]