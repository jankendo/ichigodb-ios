$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$iconDir = Join-Path $root "iOS/Assets.xcassets/AppIcon.appiconset"
$markDir = Join-Path $root "iOS/Assets.xcassets/AppMark.imageset"
New-Item -ItemType Directory -Force -Path $iconDir, $markDir | Out-Null

function New-BrandPng {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][int]$Size
  )

  $bmp = New-Object System.Drawing.Bitmap $Size, $Size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)

  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    [System.Drawing.Rectangle]::new(0,0,$Size,$Size),
    [System.Drawing.Color]::FromArgb(255,255,248,248),
    [System.Drawing.Color]::FromArgb(255,244,250,246),
    45
  )
  $g.FillRectangle($bg, 0, 0, $Size, $Size)

  $shadow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(36, 140, 22, 38))
  $g.FillEllipse($shadow, $Size*0.22, $Size*0.25, $Size*0.60, $Size*0.62)

  $berry = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    [System.Drawing.RectangleF]::new($Size*0.20,$Size*0.18,$Size*0.60,$Size*0.68),
    [System.Drawing.Color]::FromArgb(255, 246, 64, 84),
    [System.Drawing.Color]::FromArgb(255, 170, 18, 42),
    75
  )
  $g.FillEllipse($berry, $Size*0.20, $Size*0.20, $Size*0.60, $Size*0.66)

  $leafBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 37, 137, 83))
  $leafPath = New-Object System.Drawing.Drawing2D.GraphicsPath
  [System.Drawing.PointF[]]$leafPoints = @(
    [System.Drawing.PointF]::new($Size*0.50,$Size*0.14),
    [System.Drawing.PointF]::new($Size*0.39,$Size*0.28),
    [System.Drawing.PointF]::new($Size*0.50,$Size*0.24),
    [System.Drawing.PointF]::new($Size*0.61,$Size*0.28)
  )
  $leafPath.AddPolygon($leafPoints)
  $g.FillPath($leafBrush, $leafPath)

  $dbPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(235,255,255,255)), ([Math]::Max(2, $Size*0.035))
  $g.DrawEllipse($dbPen, $Size*0.34, $Size*0.43, $Size*0.32, $Size*0.13)
  $g.DrawArc($dbPen, $Size*0.34, $Size*0.55, $Size*0.32, $Size*0.13, 0, 180)
  $g.DrawLine($dbPen, $Size*0.34, $Size*0.495, $Size*0.34, $Size*0.615)
  $g.DrawLine($dbPen, $Size*0.66, $Size*0.495, $Size*0.66, $Size*0.615)

  $seedBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230,255,218,120))
  foreach ($p in @(
    @(0.35,0.35), @(0.49,0.33), @(0.63,0.36),
    @(0.30,0.50), @(0.70,0.50),
    @(0.38,0.68), @(0.52,0.72), @(0.64,0.66)
  )) {
    $g.FillEllipse($seedBrush, $Size*$p[0], $Size*$p[1], [Math]::Max(2,$Size*0.045), [Math]::Max(2,$Size*0.022))
  }

  $g.Dispose()
  $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

$icons = @{
  "Icon-20@2x.png" = 40; "Icon-20@3x.png" = 60;
  "Icon-29@2x.png" = 58; "Icon-29@3x.png" = 87;
  "Icon-40@2x.png" = 80; "Icon-40@3x.png" = 120;
  "Icon-60@2x.png" = 120; "Icon-60@3x.png" = 180;
  "Icon-20@1x-ipad.png" = 20; "Icon-20@2x-ipad.png" = 40;
  "Icon-29@1x-ipad.png" = 29; "Icon-29@2x-ipad.png" = 58;
  "Icon-40@1x-ipad.png" = 40; "Icon-40@2x-ipad.png" = 80;
  "Icon-76@1x-ipad.png" = 76; "Icon-76@2x-ipad.png" = 152;
  "Icon-83.5@2x-ipad.png" = 167; "Icon-1024.png" = 1024
}

foreach ($name in $icons.Keys) {
  New-BrandPng -Path (Join-Path $iconDir $name) -Size $icons[$name]
}

New-BrandPng -Path (Join-Path $markDir "AppMark.png") -Size 128
New-BrandPng -Path (Join-Path $markDir "AppMark@2x.png") -Size 256
New-BrandPng -Path (Join-Path $markDir "AppMark@3x.png") -Size 384

Write-Host "Generated IchigoDB brand assets."
