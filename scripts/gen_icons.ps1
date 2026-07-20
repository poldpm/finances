# Genera les icones PNG de la PWA a partir del mateix motiu que el favicon:
# tres barres ascendents sobre el verd de la marca.
# Ús:  powershell -ExecutionPolicy Bypass -File scripts\gen_icons.ps1
Add-Type -AssemblyName System.Drawing

$outDir = Join-Path $PSScriptRoot '..\img'
$bgHex  = '#0F5D4E'
$bars   = @('#8FE0C6', '#CFF3E5', '#FFFFFF')

function New-Icon {
    param([int]$Size, [string]$Path, [double]$Inset, [bool]$RoundedBg)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'

    $bg = [System.Drawing.ColorTranslator]::FromHtml($bgHex)
    if ($RoundedBg) {
        $g.Clear([System.Drawing.Color]::Transparent)
        $r  = $Size * 0.234                       # mateix radi relatiu que el SVG (15/64)
        $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
        $gp.AddArc(0, 0, $r*2, $r*2, 180, 90)
        $gp.AddArc($Size-$r*2, 0, $r*2, $r*2, 270, 90)
        $gp.AddArc($Size-$r*2, $Size-$r*2, $r*2, $r*2, 0, 90)
        $gp.AddArc(0, $Size-$r*2, $r*2, $r*2, 90, 90)
        $gp.CloseFigure()
        $g.FillPath((New-Object System.Drawing.SolidBrush($bg)), $gp)
    } else {
        $g.Clear($bg)                             # maskable: fons a sang
    }

    # Barres, en coordenades relatives a un llenç de 64 amb marge extra si cal
    $s = $Size / 64.0
    $k = 1.0 - $Inset                             # escala del motiu (maskable el vol més petit)
    $cx = $Size / 2.0
    $geom = @(
        @{ x = 14.0;  y = 34.0; w = 9.0; h = 17.0 },
        @{ x = 27.5;  y = 24.0; w = 9.0; h = 27.0 },
        @{ x = 41.0;  y = 14.0; w = 9.0; h = 37.0 }
    )
    for ($i = 0; $i -lt 3; $i++) {
        $b = $geom[$i]
        $w = $b.w * $s * $k
        $h = $b.h * $s * $k
        $x = $cx + (($b.x + $b.w/2) - 32.0) * $s * $k - $w/2
        $y = $Size/2.0 + (($b.y + $b.h/2) - 32.0) * $s * $k - $h/2
        $col = [System.Drawing.ColorTranslator]::FromHtml($bars[$i])
        $rad = $w / 2.0
        $gp2 = New-Object System.Drawing.Drawing2D.GraphicsPath
        $gp2.AddArc($x, $y, $rad*2, $rad*2, 180, 90)
        $gp2.AddArc($x+$w-$rad*2, $y, $rad*2, $rad*2, 270, 90)
        $gp2.AddArc($x+$w-$rad*2, $y+$h-$rad*2, $rad*2, $rad*2, 0, 90)
        $gp2.AddArc($x, $y+$h-$rad*2, $rad*2, $rad*2, 90, 90)
        $gp2.CloseFigure()
        $g.FillPath((New-Object System.Drawing.SolidBrush($col)), $gp2)
    }

    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "  $Path"
}

Write-Output 'Generant icones:'
New-Icon -Size 192 -Path (Join-Path $outDir 'icon-192.png')      -Inset 0.00 -RoundedBg $true
New-Icon -Size 512 -Path (Join-Path $outDir 'icon-512.png')      -Inset 0.00 -RoundedBg $true
New-Icon -Size 512 -Path (Join-Path $outDir 'icon-maskable.png') -Inset 0.28 -RoundedBg $false
Write-Output 'Fet.'
