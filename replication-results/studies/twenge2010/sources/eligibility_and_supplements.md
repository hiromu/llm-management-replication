# Eligibility and supplement check: twenge2010

Search date: 2026-10-28 (UTC). Role: eligibility and documentary-source role (coordinator subagent, Claude Opus 5.5). Full logs are in sources/eligibility_check.json and sources/supplement_search.json.

## Author package availability

Conclusion: none_found_after_documented_search.

27 documented checks covered Crossref (record and relation search), DataCite (keyword and related-identifier search), the ICPSR bibliography, openICPSR, Zenodo, Harvard Dataverse, OSF, figshare, GitHub, OpenAlex, Semantic Scholar, Twenge's research page, Campbell's Kennesaw State DigitalCommons record and general web searches covering all four authors. None turned up an author-provided replication data or code package. The ICPSR bibliography record for the article (https://www.icpsr.umich.edu/web/ICPSR/search/publications?q=%22Generational%20Differences%20in%20Work%20Values%22) links it to the original Monitoring the Future studies 7927 (1976), 9871 (1991) and 20022 (2006). Those are public original source data, not an author package. The DataCite related-identifier links (ICPSR 7927 and 20022 records) are the same citation links. Nothing was downloaded.

Limitations: the SAGE article and supplement pages returned HTTP 403. openICPSR search returned HTTP 500. The figshare keyword search could not be run directly. The OSF full-text search endpoint is retired, so a title-filter search was used instead. Google Scholar was not queried directly. These gaps were covered indirectly through DataCite, the ICPSR bibliography and web searches. On current evidence the paper meets the package-selection criterion.

## Supplements and corrections

The local catalog (papers/supplements/catalog.json) has no entry for JOM_2010_Twenge. The article does not mention an appendix, online supplement, or data or code availability. Crossref lists no supplementary material, relation or update. The SAGE supplementary tab could not be inspected (HTTP 403). No supplement was found, so nothing was saved to sources/supplements/.

No erratum, corrigendum or retraction was found. The Crossref record has no update-to or updated-by entries, and no Crossref relation points to the DOI. A Crossref search of Journal of Management errata found none for this article. OpenAlex reports is_retracted false. Web searches found no notice. The Crossref Labs Retraction Watch endpoint needs a contact email and was not queried.

Alternate copies seen in search results were not opened or downloaded: a metadata-only Kennesaw State repository record, a manuscript .docx in a UGA psychology folder and a Psychology Today-hosted PDF. The supplied version of record governs.

## Article identity

papers/journal_collection/JOM/JOM_2010_Twenge.pdf has sha256 b556175cc775fe710cca7f8e83c571c4fe8b4bb7ebb7a0878939e6eb36f0042e, which matches STUDY.json. The file is 217,359 bytes with 26 pages. The PDF text confirms the title, the authors Twenge, Campbell, Hoffman and Lance, DOI 10.1177/0149206309352246, and Journal of Management 36(5), September 2010, pp. 1117-1142. PDF page n corresponds to journal page 1116+n. The data source is named on PDF p. 9 (journal p. 1125, Monitoring the Future and www.monitoringthefuture.org) and in the ICPSR data citation on PDF p. 24 (journal p. 1140). LISREL 8.7 is named on PDF p. 10 (journal p. 1126). The article contains no code or code links. Its printed tables are sealed targets only.

Recommended publication packet: main article only.
