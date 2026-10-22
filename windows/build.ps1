$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
dotnet test (Join-Path $root "src\CursorTokens.Core.Tests\CursorTokens.Core.Tests.csproj")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dotnet build (Join-Path $root "src\CursorTokens.App\CursorTokens.App.csproj") -c Release -p:Platform=x64
exit $LASTEXITCODE
