wget -q -O rgl_whitelist_6s.txt https://whitelist.tf/rgl_6v6.txt
wget -q -O rgl_whitelist_HL.txt https://whitelist.tf/rgl_9v9.txt
wget -q -O rgl_whitelist_mm.txt https://whitelist.tf/rgl_nr6s.txt
wget -q -O rgl_whitelist_7s.txt https://whitelist.tf/rgl_7v7.txt
sixes_lines=$(wc -l < rgl_whitelist_6s.txt)
hl_lines=$(wc -l < rgl_whitelist_HL.txt)
mm_lines=$(wc -l < rgl_whitelist_mm.txt)
pl_lines=$(wc -l < rgl_whitelist_7s.txt)
sixes_lines=$(wc -l < rgl_whitelist_6s.txt)
if [[ $sixes_lines -le 50 ]]; 
then
    echo "Sixes: Number of lines is less than 50."
    exit 1
elif [[ $hl_lines -le 50 ]]
then
    echo "HL: Number of lines is less than 50." 
    exit 1
elif [[ $mm_lines -le 50 ]]
then
    echo "MM: Number of lines is less than 50." 
    exit 1
elif [[ $pl_lines -le 50 ]]
then
    echo "PL: Number of lines is less than 50." 
    exit 1
fi

echo "Whitelist Checks Complete"