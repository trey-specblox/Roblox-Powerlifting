<#
    build_front_sign_art.ps1  (Starter Gym outside name sign, 2026-10-21)

    The back-muscle art (art/logos/EPG_NameWallArt_1-3.png, 2170 x 690, the
    name wall's shape) is about 3 times wider than tall, but the outside sign
    is 60 x 8 studs (7.5 times). So that the art fills the WHOLE sign without
    squashing the figure (user, 2026-10-21), this draws a wide version:
      - behind: the art enlarged to the sign's full width, blurred and
        darkened, so its red smoke runs from end to end;
      - in front: the sharp art at the sign's full height, in the middle.
    It is flattened onto the sign panel's dark colour and cut into pieces of
    at most 1024 pixels (Roblox shrinks wider images):
      art/logos/EPG_FrontSignArt_1.png .. _4.png  (960 x 512 each)

    Run from the project root:  powershell -File art/scripts/build_front_sign_art.ps1
    Then upload the pieces (game's group as creator) and put their IDs in
    StarterGymConfig.FrontSignArt.
#>

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$logos = Join-Path $root 'art\logos'

$pieceCount = 4
$pieceW = 960
$pixW = $pieceW * $pieceCount # 3840
$pixH = 512                   # 3840 / 512 = 7.5, the sign's 60 x 8

# Rebuild the art from its three pieces.
$parts = 1..3 | ForEach-Object { [System.Drawing.Image]::FromFile((Join-Path $logos "EPG_NameWallArt_$_.png")) }
$artW = ($parts | Measure-Object -Property Width -Sum).Sum
$artH = $parts[0].Height
$art = New-Object System.Drawing.Bitmap $artW, $artH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$ga = [System.Drawing.Graphics]::FromImage($art)
$x = 0
foreach ($p in $parts) { $ga.DrawImage($p, $x, 0, $p.Width, $p.Height); $x += $p.Width; $p.Dispose() }
$ga.Dispose()

$out = New-Object System.Drawing.Bitmap $pixW, $pixH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($out)
$g.InterpolationMode = 'HighQualityBicubic'
$g.PixelOffsetMode = 'HighQuality'
$g.CompositingQuality = 'HighQuality'
$g.Clear([System.Drawing.Color]::FromArgb(255, 22, 22, 24)) # the sign panel's colour

# Behind: the art covering the full width, blurred by shrinking it a lot and
# enlarging it again, then darkened.
$coverH = [int][Math]::Round($pixW * $artH / $artW)
$small = New-Object System.Drawing.Bitmap ([int]($pixW / 24)), ([int]($coverH / 24)), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gs = [System.Drawing.Graphics]::FromImage($small)
$gs.InterpolationMode = 'HighQualityBicubic'
$gs.DrawImage($art, 0, 0, $small.Width, $small.Height)
$gs.Dispose()
$edges = New-Object System.Drawing.Imaging.ImageAttributes
$edges.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
$coverTop = [int](($pixH - $coverH) / 2)
$g.DrawImage($small, (New-Object System.Drawing.Rectangle 0, $coverTop, $pixW, $coverH), 0, 0, $small.Width, $small.Height,
    [System.Drawing.GraphicsUnit]::Pixel, $edges)
$small.Dispose()
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(120, 10, 10, 12))), 0, 0, $pixW, $pixH)

# In front: the sharp art at full height, in the middle (its see-through edges blend in).
$frontW = [int][Math]::Round($pixH * $artW / $artH)
$g.DrawImage($art, (New-Object System.Drawing.Rectangle ([int](($pixW - $frontW) / 2)), 0, $frontW, $pixH), 0, 0, $artW, $artH,
    [System.Drawing.GraphicsUnit]::Pixel, $edges)
$g.Dispose()
$art.Dispose()

for ($i = 0; $i -lt $pieceCount; $i++) {
    $part = $out.Clone((New-Object System.Drawing.Rectangle ($i * $pieceW), 0, $pieceW, $pixH), $out.PixelFormat)
    $path = Join-Path $logos ("EPG_FrontSignArt_{0}.png" -f ($i + 1))
    $part.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $part.Dispose()
    Write-Output ("{0}  {1} x {2}" -f $path, $pieceW, $pixH)
}
if ($args.Count -gt 0) { $out.Save($args[0], [System.Drawing.Imaging.ImageFormat]::Png) } # optional full preview
$out.Dispose()
