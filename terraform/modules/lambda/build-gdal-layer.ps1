param(
    [string]$ImageName = "windturbine-gdal-layer:python311"
)

$ErrorActionPreference = "Stop"
$ModulePath = Split-Path -Parent $MyInvocation.MyCommand.Path
$LayerPath = Join-Path $ModulePath "gdal-layer"
$ContainerName = "windturbine-gdal-layer-build"

docker build -f (Join-Path $ModulePath "gdal-layer.Dockerfile") -t $ImageName $ModulePath
docker rm $ContainerName 2>$null
docker create --name $ContainerName $ImageName | Out-Null
if (Test-Path $LayerPath) {
    Remove-Item $LayerPath -Recurse -Force
}
New-Item -ItemType Directory -Path $LayerPath | Out-Null
docker cp "${ContainerName}:/layer/." $LayerPath
docker rm $ContainerName | Out-Null

Write-Host "GDAL layer written to $LayerPath"