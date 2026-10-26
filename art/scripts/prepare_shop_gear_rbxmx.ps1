# Prepares art/roblox/ShopGear_01.rbxmx (the Shop's gear, saved from Studio
# straight after Import 3D) in the file itself: the same result as
# tools/studio/ShopGear01_PrepareImport.luau, without Studio.
#
# 2026-10-23: the first save from Studio was the raw import (grey, unanchored,
# solid, not grouped), so this applies the preparation to the file instead.
#
# What it does (keep it in step with ShopGear01_PrepareImport.luau):
#   - every MeshPart: Anchored on, CanCollide/CanTouch/CanQuery off, and the
#     Material + Color from $Looks;
#   - groups the parts into one Model per item (the name before the first
#     "_"), inside ShopGear_01;
#   - each item Model's WorldPivot: the middle of its bottom (WristWrapHanging:
#     its top), turned so its LookVector points to the item's front (from the
#     body part to the front part, level).
# It checks first and writes nothing if the file is not the expected raw
# import (exactly the 29 named MeshParts directly in ShopGear_01).
# Usage: powershell -File art/scripts/prepare_shop_gear_rbxmx.ps1 [path]
param([string]$Path = (Join-Path $PSScriptRoot "..\roblox\ShopGear_01.rbxmx"))
$ErrorActionPreference = "Stop"

# Roblox Enum.Material values.
$Fabric, $SmoothPlastic, $Metal = 1312, 272, 1088
# Color3uint8 is 0xFFRRGGBB (4278190080 = 0xFF000000; the hex literal would be negative in PowerShell 5).
function Look($material, $r, $g, $b) { @{ Material = $material; Color = [uint32](4278190080 + ($r -shl 16) + ($g -shl 8) + $b) } }
$Black = Look $Fabric 24 24 26
$Red = Look $Fabric 190 28 36
$RedPrint = Look $SmoothPlastic 210 32 40
$Grey = Look $Fabric 78 78 82
$Form = Look $SmoothPlastic 232 232 230
$Stand = Look $Metal 30 30 34
$White = Look $SmoothPlastic 238 238 238
$Looks = @{
    KneeSleeve_Body = $Black; KneeSleeve_Stripes = $Red; KneeSleeve_Patch = $RedPrint
    WristWrap_Body = $Black; WristWrap_Tail = $Black; WristWrap_Stripes = $Red; WristWrap_Text = $White
    WristWrapHanging_Body = $Black; WristWrapHanging_Loop = $Black; WristWrapHanging_Stripes = $Red
    WristWrapHanging_Velcro = $Grey; WristWrapHanging_Text = $White
    LeverBelt_Outer = (Look $Fabric 20 20 22); LeverBelt_Lining = $Red; LeverBelt_Stitch = $Grey
    LeverBelt_Lever = (Look $Metal 150 152 158); LeverBelt_Text = (Look $SmoothPlastic 22 22 24)
    MannequinSinglet_Form = $Form; MannequinSinglet_Stand = $Stand; MannequinSinglet_Black = $Black
    MannequinSinglet_Red = $Red; MannequinSinglet_Trim = $Red; MannequinSinglet_Shorts = $Black
    MannequinSinglet_ShortsRed = $Red; MannequinSinglet_Patch = $RedPrint
    MannequinTee_Form = $Form; MannequinTee_Stand = $Stand; MannequinTee_Black = $Black; MannequinTee_Logo = $RedPrint
}
# Per item: the part that marks its front, the part measured from, hangs from its top.
$Items = [ordered]@{
    KneeSleeve = @("KneeSleeve_Patch", "KneeSleeve_Body", $false)
    WristWrap = @("WristWrap_Tail", "WristWrap_Body", $false)
    WristWrapHanging = @("WristWrapHanging_Text", "WristWrapHanging_Body", $true)
    LeverBelt = @("LeverBelt_Lever", "LeverBelt_Outer", $false)
    MannequinSinglet = @("MannequinSinglet_Patch", "MannequinSinglet_Form", $false)
    MannequinTee = @("MannequinTee_Logo", "MannequinTee_Form", $false)
}

$full = (Resolve-Path $Path).Path
$xml = New-Object System.Xml.XmlDocument
$xml.PreserveWhitespace = $true
$xml.Load($full)
$root = $xml.SelectSingleNode("/roblox/Item[@class='Model']")
function NameOf($item) { $item.SelectSingleNode("Properties/string[@name='Name']").InnerText }
if ($root -eq $null -or (NameOf $root) -ne "ShopGear_01") { throw "no top Model ShopGear_01 in $full" }

# Checks: exactly the 29 expected MeshParts, directly in ShopGear_01, nothing else.
$parts = @{}
foreach ($child in $root.SelectNodes("Item")) {
    $name = NameOf $child
    if ($child.GetAttribute("class") -ne "MeshPart") { throw "REFUSED: ShopGear_01 holds a $($child.GetAttribute('class')) '$name' (already prepared?)" }
    if (-not $Looks.ContainsKey($name)) { throw "REFUSED: unexpected part '$name'" }
    if ($parts.ContainsKey($name)) { throw "REFUSED: two parts named '$name'" }
    $mesh = $child.SelectSingleNode("Properties/Content[@name='MeshId']").InnerText
    if (-not $mesh.StartsWith("rbxassetid://")) { throw "REFUSED: $name has no uploaded mesh ('$mesh')" }
    $parts[$name] = $child
}
if ($parts.Count -ne $Looks.Count) { throw "REFUSED: found $($parts.Count) of $($Looks.Count) parts" }

function SetValue($item, $type, $name, $value) {
    $node = $item.SelectSingleNode("Properties/$type[@name='$name']")
    if ($node -eq $null) { throw "$(NameOf $item) has no $type $name" }
    $node.InnerText = [string]$value
}
function Vec($item, $name) {
    $node = $item.SelectSingleNode("Properties/Vector3[@name='$name']")
    [double[]]@([double]$node.X, [double]$node.Y, [double]$node.Z)
}
function Frame($item) {
    $c = $item.SelectSingleNode("Properties/CoordinateFrame[@name='CFrame']")
    @{ P = [double[]]@([double]$c.X, [double]$c.Y, [double]$c.Z)
       R = [double[]]@($c.R00, $c.R01, $c.R02, $c.R10, $c.R11, $c.R12, $c.R20, $c.R21, $c.R22) }
}
$inv = [Globalization.CultureInfo]::InvariantCulture
function F([double]$v) { $v.ToString("R", $inv) }

foreach ($name in $parts.Keys) {
    $item = $parts[$name]
    SetValue $item "bool" "Anchored" "true"
    SetValue $item "bool" "CanCollide" "false"
    SetValue $item "bool" "CanTouch" "false"
    SetValue $item "bool" "CanQuery" "false"
    SetValue $item "token" "Material" $Looks[$name].Material
    SetValue $item "Color3uint8" "Color3uint8" $Looks[$name].Color
}

foreach ($itemName in $Items.Keys) {
    $front, $body, $hangs = $Items[$itemName]
    $members = $parts.Keys | Where-Object { $_.Split("_")[0] -eq $itemName } | Sort-Object
    # The item's world box: each part's 8 corners (works for rotated parts too).
    $lo = @([double]::MaxValue) * 3; $hi = @([double]::MinValue) * 3
    foreach ($m in $members) {
        $f = Frame $parts[$m]; $s = Vec $parts[$m] "size"
        foreach ($sx in -1, 1) { foreach ($sy in -1, 1) { foreach ($sz in -1, 1) {
            $l = @(($sx * $s[0] / 2), ($sy * $s[1] / 2), ($sz * $s[2] / 2))
            for ($i = 0; $i -lt 3; $i++) {
                $w = $f.P[$i] + $f.R[3 * $i] * $l[0] + $f.R[3 * $i + 1] * $l[1] + $f.R[3 * $i + 2] * $l[2]
                if ($w -lt $lo[$i]) { $lo[$i] = $w }; if ($w -gt $hi[$i]) { $hi[$i] = $w }
            }
        } } }
    }
    $anchor = @((($lo[0] + $hi[0]) / 2), $(if ($hangs) { $hi[1] } else { $lo[1] }), (($lo[2] + $hi[2]) / 2))
    $pf = (Frame $parts[$front]).P; $pb = (Frame $parts[$body]).P
    $fx, $fz = ($pf[0] - $pb[0]), ($pf[2] - $pb[2])
    $len = [Math]::Sqrt($fx * $fx + $fz * $fz)
    if ($len -lt 0.001) { $fx, $fz, $len = 0, -1, 1 }
    $fx /= $len; $fz /= $len
    # CFrame.lookAt: right = look x up = (-fz, 0, fx), up = (0, 1, 0), back = -look.
    $r = @((-$fz), 0, (-$fx), 0, 1, 0, $fx, 0, (-$fz))

    $model = $xml.CreateElement("Item")
    $model.SetAttribute("class", "Model")
    $model.SetAttribute("referent", "RBX" + [Guid]::NewGuid().ToString("N").ToUpper())
    $props = $xml.CreateElement("Properties")
    $nameNode = $xml.CreateElement("string"); $nameNode.SetAttribute("name", "Name"); $nameNode.InnerText = $itemName
    $pivot = $xml.CreateElement("OptionalCoordinateFrame"); $pivot.SetAttribute("name", "WorldPivotData")
    $cf = $xml.CreateElement("CFrame")
    $values = [ordered]@{ X = $anchor[0]; Y = $anchor[1]; Z = $anchor[2]; R00 = $r[0]; R01 = $r[1]; R02 = $r[2];
        R10 = $r[3]; R11 = $r[4]; R12 = $r[5]; R20 = $r[6]; R21 = $r[7]; R22 = $r[8] }
    foreach ($k in $values.Keys) { $e = $xml.CreateElement($k); $e.InnerText = F $values[$k]; [void]$cf.AppendChild($e) }
    [void]$pivot.AppendChild($cf); [void]$props.AppendChild($nameNode); [void]$props.AppendChild($pivot)
    [void]$model.AppendChild($props)
    foreach ($m in $members) { [void]$model.AppendChild($root.RemoveChild($parts[$m])) }
    [void]$root.AppendChild($model)
    "{0}: {1} parts, {2:N2} x {3:N2} x {4:N2}, pivot ({5:N2}, {6:N2}, {7:N2}) facing ({8:N2}, 0, {9:N2})" -f $itemName,
        $members.Count, ($hi[0] - $lo[0]), ($hi[1] - $lo[1]), ($hi[2] - $lo[2]), $anchor[0], $anchor[1], $anchor[2], $fx, $fz
}

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)
$settings.OmitXmlDeclaration = $true
$writer = [System.Xml.XmlWriter]::Create($full, $settings)
$xml.Save($writer)
$writer.Close()
"prepared $($parts.Count) MeshParts in $($Items.Count) items: $full"
