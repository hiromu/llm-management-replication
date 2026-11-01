# Camp location crosswalk (schema only)

An independently constructed crosswalk geocodes each camp code (field CAMP in nara_pow_rg389) to a place. The file is supplied in data/

- camp_code: three-character CAMP value as it appears in the raw field.
- in_nara_code_list: whether the code is defined in pow_CAMP_cl1277.csv.
- nara_code_text, nara_comment, nara_degree_coords_text: the code-list meaning, comment and NARA's whole-degree latitude-longitude text.
- identified_place_name, country_iso2, country: place identified from the NARA text.
- latitude, longitude: decimal degrees (WGS84) of the identified place.
- geocoding_source, geonames_id, source_url: GeoNames gazetteer record or other public source used.
- confidence: exact (place identified and geocoded), approximate (place uncertain or only NARA whole-degree point usable), unknown (no location identifiable; latitude/longitude empty).
- ambiguous, alt_place_name, alt_country_iso2, alt_latitude, alt_longitude, alt_source_url: an alternative identification where the NARA text is ambiguous.
- km_primary_to_nara_degree_point: distance between the geocoded point and NARA's whole-degree point.
- duplicate_code_in_nara_list: true for the codes with two meanings in the NARA list (359, 510).
- note: free-text remarks.

National capitals for reference: Berlin and Tokyo coordinates are not in the crosswalk; a distance rule must state the capital coordinates and the distance formula to use.
