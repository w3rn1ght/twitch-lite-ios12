# Generates the app icon and launch images for Twitch Lite.
# Requires Windows PowerShell (System.Drawing).
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$res  = Join-Path $root "Resources"
New-Item -ItemType Directory -Force -Path $res | Out-Null

function New-Brush([string]$hex) {
    return New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($hex))
}

function Draw-TwitchLogo([System.Drawing.Graphics]$g, [float]$x, [float]$y, [float]$w, [float]$h, [string]$bubbleColor, [string]$eyeColor) {
    $r = [float]($w * 0.06)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bx = $x + $w * 0.16
    $by = $y + $h * 0.14
    $bw = $w * 0.68
    $bh = $h * 0.58
    $path.AddArc([float]$bx, [float]$by, [float]($r*2), [float]($r*2), 180, 90)
    $path.AddLine([float]($bx+$r), [float]$by, [float]($bx+$bw-$r), [float]$by)
    $path.AddArc([float]($bx+$bw-$r*2), [float]$by, [float]($r*2), [float]($r*2), 270, 90)
    $path.AddLine([float]($bx+$bw), [float]($by+$r), [float]($bx+$bw), [float]($by+$bh-$r))
    $path.AddArc([float]($bx+$bw-$r*2), [float]($by+$bh-$r*2), [float]($r*2), [float]($r*2), 0, 90)
    $path.AddLine([float]($bx+$bw-$r), [float]($by+$bh), [float]($bx+$bw*0.64), [float]($by+$bh))
    $path.AddLine([float]($bx+$bw*0.64), [float]($by+$bh+$h*0.12), [float]($bx+$bw*0.46), [float]($by+$bh))
    $path.AddLine([float]($bx+$bw*0.46), [float]($by+$bh), [float]($bx+$r), [float]($by+$bh))
    $path.AddArc([float]$bx, [float]($by+$bh-$r*2), [float]($r*2), [float]($r*2), 90, 90)
    $path.CloseFigure()

    $bubble = New-Brush $bubbleColor
    $g.FillPath($bubble, $path)
    $bubble.Dispose()

    $eye = New-Brush $eyeColor
    $ew = [float]($bw * 0.11)
    $eh = [float]($bh * 0.42)
    $ey = [float]($by + $bh * 0.25)
    $ex1 = [float]($bx + $bw * 0.28)
    $ex2 = [float]($bx + $bw * 0.58)
    $g.FillRectangle($eye, $ex1, $ey, $ew, $eh)
    $g.FillRectangle($eye, $ex2, $ey, $ew, $eh)
    $eye.Dispose()
    $path.Dispose()
}

function Save-AppIcon([int]$size, [string]$file) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $rect = New-Object System.Drawing.Rectangle 0, 0, $size, $size
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.ColorTranslator]::FromHtml("#9147ff")), ([System.Drawing.ColorTranslator]::FromHtml("#5c16c5")), 45.0
    $g.FillRectangle($bg, $rect)
    $bg.Dispose()

    # Soft purple glow.
    $glow = New-Object System.Drawing.Drawing2D.GraphicsPath
    $glow.AddEllipse([float]($size*0.08), [float]($size*0.08), [float]($size*0.84), [float]($size*0.84))
    $pgr = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
    $pgr.CenterColor = [System.Drawing.Color]::FromArgb(70, 255, 255, 255)
    $pgr.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
    $g.FillPath($pgr, $glow)
    $pgr.Dispose(); $glow.Dispose()

    Draw-TwitchLogo $g 0 0 $size $size "#ffffff" "#6b21d8"
    $bmp.Save((Join-Path $res $file), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

function Save-Launch([int]$pw, [int]$ph, [int]$scale, [string]$file) {
    $w = $pw * $scale
    $h = $ph * $scale
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.ColorTranslator]::FromHtml("#0e0e10"))

    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, ([System.Drawing.ColorTranslator]::FromHtml("#18181b")), ([System.Drawing.ColorTranslator]::FromHtml("#0e0e10")), 90.0
    $g.FillRectangle($bg, $rect); $bg.Dispose()

    $logoSize = [Math]::Min($w, $h) * 0.24
    $lx = ($w - $logoSize) / 2
    $ly = ($h - $logoSize) / 2 - [Math]::Min($w, $h) * 0.05
    Draw-TwitchLogo $g $lx $ly $logoSize $logoSize "#ffffff" "#9147ff"

    $fontSize = [Math]::Max(10, [int]([Math]::Min($w, $h) * 0.035))
    $font = New-Object System.Drawing.Font "Segoe UI", $fontSize, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $brush = New-Brush "#efeff1"
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $textRect = New-Object System.Drawing.RectangleF 0, ($ly + $logoSize + $fontSize * 0.7), $w, ($fontSize * 2)
    $g.DrawString("TWITCH LITE", $font, $brush, $textRect, $sf)
    $font.Dispose(); $brush.Dispose()

    $bmp.Save((Join-Path $res $file), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

$icons = @(
    @(40, "Icon-20@2x.png"), @(60, "Icon-20@3x.png"),
    @(58, "Icon-29@2x.png"), @(87, "Icon-29@3x.png"),
    @(80, "Icon-40@2x.png"), @(120, "Icon-40@3x.png"),
    @(120, "Icon-60@2x.png"), @(180, "Icon-60@3x.png"),
    @(76, "Icon-76.png"), @(152, "Icon-76@2x.png"),
    @(167, "Icon-83.5@2x.png"), @(1024, "Icon-1024.png")
)
foreach ($i in $icons) { Save-AppIcon ([int]$i[0]) ([string]$i[1]) }

$launches = @(
    @(320,568,2), @(320,568,3),
    @(375,667,2), @(375,667,3),
    @(414,736,2), @(414,736,3),
    @(375,812,2), @(375,812,3),
    @(414,896,2), @(414,896,3),
    @(768,1024,2), @(834,1112,2), @(834,1194,2), @(1024,1366,2),
    @(568,320,2), @(568,320,3),
    @(667,375,2), @(667,375,3),
    @(736,414,2), @(736,414,3),
    @(812,375,2), @(812,375,3),
    @(896,414,2), @(896,414,3),
    @(1024,768,2), @(1112,834,2), @(1194,834,2), @(1366,1024,2)
)
foreach ($l in $launches) {
    $suffix = if ([int]$l[2] -eq 2) { "@2x" } else { "@3x" }
    Save-Launch ([int]$l[0]) ([int]$l[1]) ([int]$l[2]) ("Launch-{0}x{1}{2}.png" -f $l[0], $l[1], $suffix)
}

Write-Host "Generated $($icons.Count) icons and $($launches.Count) launch images in $res"
