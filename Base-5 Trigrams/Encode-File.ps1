param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

# Base91 alphabet
$alphabet = (
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" +
    "!#$%&()*+,./:;<=>?@[]^_`{|}~"""
)

function Encode-Base91([byte[]]$bytes) {
    $b = 0
    $n = 0
    $out = ""

    foreach ($byte in $bytes) {
        $b = $b -bor ($byte -shl $n)
        $n += 8
        if ($n -gt 13) {
            $v = $b -band 8191
            if ($v -gt 88) {
                $b = $b -shr 13
                $n -= 13
            } else {
                $v = $b -band 16383
                $b = $b -shr 14
                $n -= 14
            }
            $out += $alphabet[$v % 91]
            $out += $alphabet[$v / 91]
        }
    }

    if ($n -gt 0) {
        $out += $alphabet[$b % 91]
        if ($n -gt 7 -or $b -gt 90) {
            $out += $alphabet[$b / 91]
        }
    }

    return $out
}

# Read file
$data = [System.IO.File]::ReadAllBytes($InputFile)

# Compress using GZip (more stable than raw Deflate)
$ms = New-Object System.IO.MemoryStream
$gzip = New-Object System.IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]::Compress)
$gzip.Write($data, 0, $data.Length)
$gzip.Close()
$compressed = $ms.ToArray()

# Encode
$encoded = Encode-Base91 $compressed

# Save encoded output
Set-Content -Path $OutputFile -Value $encoded
