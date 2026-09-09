FROM public.ecr.aws/amazonlinux/amazonlinux:2023

RUN dnf install -y gdal gdal-libs \
    && mkdir -p /layer/bin /layer/lib /layer/share \
    && cp -L /usr/bin/ogr2ogr /layer/bin/ogr2ogr \
    && for library in $(ldd /usr/bin/ogr2ogr | awk '/=> \/|^\// {print $3?$3:$1}' | grep '^/'); do cp -L "$library" /layer/lib/; done \
    && cp -a /usr/share/gdal /layer/share/gdal \
    && cp -a /usr/share/proj /layer/share/proj