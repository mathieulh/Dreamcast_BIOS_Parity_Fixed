<#
.SYNOPSIS
    Fixes the HOLLY parity check of a Dreamcast/NAOMI SH‑4 BIOS ROM.
    The script leaves the executable code untouched by only modifying
    the trailing zero‑padding area.

.PARAMETER InputFile
    Path to the original BIOS image (e.g. dc_boot.bin).

.PARAMETER OutputFile
    Path where the fixed image will be written.

.EXAMPLE
    .\Fix-BiosParitySafe.ps1 -InputFile dc_boot.bin -OutputFile dc_boot_fixed.bin
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

# -------------------------------------------------
# 1. Load the whole file as a byte array
# -------------------------------------------------
$bytes = [System.IO.File]::ReadAllBytes($InputFile)

# -------------------------------------------------
# 2. Compute XOR of all bytes
# -------------------------------------------------
$xorAll = 0
foreach ($b in $bytes) {
    $xorAll = $xorAll -bxor $b
}

# -------------------------------------------------
# 3. Function that returns the parity of a byte
#    (0 = even number of 1‑bits, 1 = odd)
# -------------------------------------------------
function Get-Parity([byte]$v) {
    $p = $v
    $p = $p -bxor ($p -shr 4)
    $p = $p -bxor ($p -shr 2)
    $p = $p -bxor ($p -shr 1)
    return $p -band 1
}

$parity = Get-Parity $xorAll   # 0 = even, 1 = odd

# -------------------------------------------------
# 4. If parity is odd, flip one bit in the padding area
# -------------------------------------------------
if ($parity -eq 1) {
    Write-Host "Parity is odd (XOR = 0x{0:X2}) – fixing by flipping a bit in the padding." -f $xorAll

    # Find the first byte of the trailing zero‑padding.
    # We already know the last non‑zero offset for dc_boot.bin is 0x1FFDFF,
    # but we compute it generically so the script works on any similar ROM.
    $len = $bytes.Length
    $lastNonZero = -1
    for ($i = $len - 1; $i -ge 0; $i--) {
        if ($bytes[$i] -ne 0) {
            $lastNonZero = $i
            break
        }
    }
    if ($lastNonZero -lt 0) {
        throw "The file appears to be all zero – nothing to fix."
    }
    $padStart = $lastNonZero + 1          # first byte after the last non‑zero byte
    if ($padStart -ge $len) {
        throw "No padding found – the file ends with non‑zero data."
    }

    # Flip the least‑significant bit of the first padding byte.
    $bytes[$padStart] = $bytes[$padStart] -bxor 0x01
    Write-Host ("Flipped bit 0 of byte at offset 0x{0:X8} (was {1:X2}, now {2:X2})" `
                -f $padStart,
                ($bytes[$padStart] -bxor 0x01),
                $bytes[$padStart])
}
else {
    Write-Host "Parity is already even (XOR = 0x{0:X2}) – no change needed." -f $xorAll
}

# -------------------------------------------------
# 5. Write the (possibly) corrected image
# -------------------------------------------------
[System.IO.File]::WriteAllBytes($OutputFile, $bytes)
Write-Host "Written fixed image to '$OutputFile'"