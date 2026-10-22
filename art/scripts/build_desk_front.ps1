<#
    build_desk_front.ps1  (Starter Gym reception, 2026-10-21)

    Draws the reception desk's whole front as one picture and cuts it into
    three 1024-pixel-wide pieces for Roblox (Roblox shrinks wider images):
      art/logos/EPG_DeskFront_1.png .. _3.png

    Why a picture: drawn in Roblox (tilted GUI shapes, Marble) the details had
    jagged edges and flickered. Drawn here everything is smooth.

    The picture is the desk front's face, 22 x 4.1 studs: a white brushed
    background with faint diagonal lines, red and black speed slashes at both
    ends, a black band with red lines behind the letters, chrome trim along
    the top and bottom, and the user's "SBD Central" logo banner (rebuilt from
    art/logos/SBDCentral_DeskBanner_1-3.png) in the middle, 4 studs tall.

    Run from the project root:  powershell -File art/scripts/build_desk_front.ps1
    Then upload the three pieces (game's group as creator) and put their IDs
    in StarterGymConfig.DeskFrontPieces.
#>

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logos = Join-Path $root 'art\logos'

# The face, in studs, and the picture's size.
$faceStudsW = 22.0
$faceStudsH = 4.1
$pieceCount = 3
$pixW = 1024 * $pieceCount
$pps = $pixW / $faceStudsW
$pixH = [int][Math]::Round($faceStudsH * $pps)

function Px([double]$studs) { return [float]($studs * $script:pps) }
function Rgb([int]$r, [int]$g, [int]$b, [int]$a = 255) { return [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

$bmp = New-Object System.Drawing.Bitmap $pixW, $pixH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode = 'HighQuality'
$g.CompositingQuality = 'HighQuality'

$red = Rgb 200 22 32
$black = Rgb 22 22 24
$trim = 0.1

# Background: brushed white, a touch darker toward the bottom.
$full = New-Object System.Drawing.RectangleF 0, 0, $pixW, $pixH
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $full, (Rgb 252 252 251), (Rgb 232 232 230), 90.0
$g.FillRectangle($bg, $full)

# Everything else stays between the trims.
$g.SetClip((New-Object System.Drawing.RectangleF 0, (Px $trim), $pixW, ($pixH - 2 * (Px $trim))))

# Faint diagonal lines, a light texture over the white.
$texture = New-Object System.Drawing.Pen (Rgb 0 0 0 14), (Px 0.04)
for ($x = -$faceStudsH; $x -lt $faceStudsW + $faceStudsH; $x += 0.35) {
    $g.DrawLine($texture, (Px $x), (Px $faceStudsH), (Px ($x + $faceStudsH * 0.6)), 0)
}

# Speed slashes at both ends, leaning toward the middle at the top.
function Slash($color, [double]$cx, [double]$angle) {
    $state = $script:g.Save()
    $script:g.TranslateTransform((Px $cx), (Px ($script:faceStudsH / 2)))
    $script:g.RotateTransform([float]$angle)
    $brush = New-Object System.Drawing.SolidBrush $color
    $script:g.FillRectangle($brush, (Px -0.12), (Px -2.2), (Px 0.24), (Px 4.4))
    $script:g.Restore($state)
}
foreach ($side in 1, -1) {
    for ($i = 0; $i -lt 4; $i++) {
        $fromEnd = 1.15 + $i * 0.5
        $cx = if ($side -eq 1) { $fromEnd } else { $faceStudsW - $fromEnd }
        $color = if ($i % 2 -eq 0) { $black } else { $red }
        Slash $color $cx (25 * $side)
    }
}

# The black band behind the letters, with a thin red line above and below.
$bandTop = 2.05; $bandH = 1.5; $margin = 0.3; $line = 0.07; $gap = 0.06
$g.FillRectangle((New-Object System.Drawing.SolidBrush $black), (Px $margin), (Px $bandTop), (Px ($faceStudsW - 2 * $margin)), (Px $bandH))
$redBrush = New-Object System.Drawing.SolidBrush $red
$g.FillRectangle($redBrush, (Px $margin), (Px ($bandTop - $gap - $line)), (Px ($faceStudsW - 2 * $margin)), (Px $line))
$g.FillRectangle($redBrush, (Px $margin), (Px ($bandTop + $bandH + $gap)), (Px ($faceStudsW - 2 * $margin)), (Px $line))
$g.ResetClip()

# Chrome trim along the top and bottom edges.
foreach ($y in 0, ($faceStudsH - $trim)) {
    $rect = New-Object System.Drawing.RectangleF 0, (Px $y), $pixW, (Px $trim)
    $chrome = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (Rgb 255 255 255), (Rgb 120 122 128), 90.0
    $blend = New-Object System.Drawing.Drawing2D.ColorBlend 4
    $blend.Colors = @((Rgb 150 152 158), (Rgb 255 255 255), (Rgb 120 122 128), (Rgb 215 217 222))
    $blend.Positions = @(0.0, 0.35, 0.65, 1.0)
    $chrome.InterpolationColors = $blend
    $g.FillRectangle($chrome, $rect)
}

# The logo banner, rebuilt from its three pieces, 4 studs tall in the middle.
$pieces = 1..3 | ForEach-Object { [System.Drawing.Image]::FromFile((Join-Path $logos "SBDCentral_DeskBanner_$_.png")) }
$logoPixW = ($pieces | Measure-Object -Property Width -Sum).Sum
$logoPixH = $pieces[0].Height
$logoH = Px 4.0
$logoW = $logoH * $logoPixW / $logoPixH
$left = ($pixW - $logoW) / 2
$top = ($pixH - $logoH) / 2
$edges = New-Object System.Drawing.Imaging.ImageAttributes
$edges.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY) # no seams where the pieces meet
$before = 0
foreach ($piece in $pieces) {
    $x0 = [int][Math]::Round($left + $logoW * $before / $logoPixW)
    $x1 = [int][Math]::Round($left + $logoW * ($before + $piece.Width) / $logoPixW)
    $dest = New-Object System.Drawing.Rectangle $x0, ([int][Math]::Round($top)), ($x1 - $x0), ([int][Math]::Round($logoH))
    $g.DrawImage($piece, $dest, 0, 0, $piece.Width, $piece.Height, [System.Drawing.GraphicsUnit]::Pixel, $edges)
    $before += $piece.Width
    $piece.Dispose()
}
$g.Dispose()

# Cut into the pieces for Roblox.
for ($i = 0; $i -lt $pieceCount; $i++) {
    $part = $bmp.Clone((New-Object System.Drawing.Rectangle ($i * 1024), 0, 1024, $pixH), $bmp.PixelFormat)
    $path = Join-Path $logos ("EPG_DeskFront_{0}.png" -f ($i + 1))
    $part.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $part.Dispose()
    Write-Output ("{0}  1024 x {1}" -f $path, $pixH)
}
if ($args.Count -gt 0) { $bmp.Save($args[0], [System.Drawing.Imaging.ImageFormat]::Png) } # optional full preview
$bmp.Dispose()
