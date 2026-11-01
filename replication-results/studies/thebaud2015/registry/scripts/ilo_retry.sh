#!/bin/zsh
# Retry archived ILO TRAVAIL maternity-protection country reports from the Internet Archive, pacing requests.
# Usage: ilo_retry.sh <study_dir>
ST=$1; F="$ST/registry/scripts/fetch.sh"
have() { [[ -s "$ST/data/raw/ilo_travail_maternity/$1" ]]; }
for y in 2011 2009; do
  if [[ $y == 2011 ]]; then ts=20120825; else ts=20100109; fi
  for c in AU AT BE CA CZ DK FI FR DE GR IS IE IT JP NL NZ NO PL PT ES SE CH GB US; do
    fn="travail_maternity_${y}_${c}.html"
    have $fn && continue
    sleep 6
    zsh $F $ST ilo_travail_maternity $fn "https://web.archive.org/web/${ts}000000id_/http://www.ilo.org:80/dyn/travail/travmain.sectionReport1?p_lang=en&p_countries=${c}&p_sc_id=2000&p_year=${y}&p_structure=3" >/dev/null
    have $fn && continue
    if [[ $y == 2011 ]]; then
      sleep 6
      zsh $F $ST ilo_travail_maternity $fn "https://web.archive.org/web/20160312000000id_/http://www.ilo.org/dyn/travail/travmain.sectionReport1?p_lang=en&p_structure=3&p_year=2011&p_start=1&p_increment=10&p_sc_id=2000&p_countries=${c}&p_print=Y" >/dev/null
    fi
  done
done
echo done
