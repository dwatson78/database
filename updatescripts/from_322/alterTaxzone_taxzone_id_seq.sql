SELECT setval('taxzone_taxzone_id_seq', MAX(taxzone_id) + 1, true) FROM taxzone;