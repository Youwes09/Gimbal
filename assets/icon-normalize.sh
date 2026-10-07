# Normalise one app icon so every icon in the shell reads as one set.
#   sh icon-normalize.sh SRC OUT
# Prints OUT on success, SRC if anything fails (the caller then shows the original).
#
#  1. Shape: rasterise, trim only clear padding (the 1px transparent border keeps -trim off
#     opaque frames), then scale by how much of its box the icon covers, so squares,
#     circles and odd shapes carry the same visual weight (a full square lands at 84% of
#     the canvas, a circle near 95%).
#  2. Colour: keep every hue, but pull saturation and lightness into one shared range.
#     Loud icons calm down, murky ones lift; nothing is pushed more saturated, so grey
#     icons stay grey.

src="$1"; out="$2"; t="$out.$$.trim.png"; o="$out.$$.png"
trap 'rm -f "$t" "$o"' EXIT

fail() { echo "$src"; exit 0; }
command -v magick >/dev/null || fail

magick -background none -density 384 "$src" -resize 512x512 \
    -bordercolor none -border 1 -trim +repage "PNG32:$t" 2>/dev/null || fail

# Coverage, and the alpha-weighted mean saturation and lightness (HSL), in one pass each.
cover=$(magick "$t" -alpha extract -format "%[fx:mean]" info:) || fail
stat() {  # $1 = HSL channel index (1 = S, 2 = L)
    magick "$t" \( +clone -alpha extract -write mpr:a +delete \) -alpha off -colorspace HSL \
        -channel "$1" -separate +channel mpr:a -compose multiply -composite \
        -format "%[fx:mean]" info:
}
sat=$(stat 1) || fail
lit=$(stat 2) || fail

# Targets: saturation at most 0.55, lightness nudged toward 0.55 within ±15%.
read -r size bri satp <<EOF
$(awk -v c="$cover" -v s="$sat" -v l="$lit" 'BEGIN {
    if (c < 0.3) c = 0.3
    sz = 0.84 / sqrt(c); if (sz > 1) sz = 1
    s /= c; l /= c                                  # per covered pixel
    sf = (s > 0.55) ? 0.55 / s : 1; if (sf < 0.7) sf = 0.7
    lf = (l > 0) ? 0.55 / l : 1; if (lf < 0.88) lf = 0.88; if (lf > 1.15) lf = 1.15
    printf "%d %d %d\n", 256 * sz, 100 * lf, 100 * sf
}')
EOF

magick "$t" -modulate "$bri,$satp,100" -resize "${size}x${size}" \
    -background none -gravity center -extent 256x256 "PNG32:$o" 2>/dev/null || fail
# Renamed into place: another instance drawing the same icon never reads it half-written.
mv -f "$o" "$out" || fail
echo "$out"
