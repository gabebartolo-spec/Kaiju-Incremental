# croc-claw young/exp_set.sh: the five baby fix1 takes (lead 10-28 23:1x) appended to game_out/young/reptilian_baby.kclip (y7, has rise_bay)
B=C:/kt/casc_drafts_1028/baby; C=C:/Users/DANTE/cascadeur_bridge/croc_new/claw
for spec in "idle 241 still" "walk 90 walk" "turn_on_the_spot 109 still" "walk_turn_left 91 still" "walk_turn_right 91 still"; do
  set -- $spec; echo "== $1 $2 $3"; timeout 1800 bash $C/exp_young.sh baby $B/$1_fix1.casc $1 0 $2 $3 2>&1 | grep -E "EXPORTED|FAILED|NO BLEND|CLIP |FOOTIK|rror" | cut -c1-260
  sleep 20
done
