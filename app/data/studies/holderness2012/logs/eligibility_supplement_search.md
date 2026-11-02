# Eligibility and supplement search: holderness2012

Searches ran on 2026-10-27, between 11:27 and 11:40 UTC. Structured log: logs/eligibility_supplement_search.json.

## Author replication package

Verdict: none found. No public data or code package from the authors turned up after the documented search, so the paper appears to meet the no-package criterion.

- The INFORMS article page loaded in the browser pane. It has no Supplemental Material, e-companion, data or code link. The /doi/suppl/ endpoint redirects to the abstract.
- Crossref shows no relations and no linked datasets.
- DataCite found 0 hits for the author pair, the title or the DOI as a related identifier. DataCite covers Dataverse, ICPSR/openICPSR, Zenodo, figshare, Mendeley Data and OSF.
- Harvard Dataverse, Zenodo, figshare, OSF and GitHub: nothing relevant.
- Pontiff's homepage links code for other papers. For this paper it links only a manuscript PDF named "POW Working January 2012 MS Forthcoming.pdf", which was not opened.
- Neither author's CV mentions data or code for this paper. Archived BC homepages contain no files about this paper.
- The article itself cites public National Archives POW data, which is a public source, not an author package.

## Supplements and corrections

- Supplements: none found. There is no e-companion or online appendix, and the article references no appendix.
- Corrections: none found. Crossref has no update notices, and Crossref searches of Management Science errata from July 2012 onward found only unrelated items. One of them, mnsc.2015.2421, concerns Burtch, Ghose and Wattal. The Vol 58 No 10 table of contents has no erratum.
- Nothing was downloaded to sources/supplements/.

## Working-paper versions

None of these were downloaded.

1. "Hierarchies or Markets? The Survival of POWs during WWII", December 2008, AEA/ASSA 2009 conference paper: https://swlb1.aeaweb.org/conference/2009/retrieve.php?pdfid=412
2. "Hierarchies and the Survival of POWs during WWII", SSRN 1345420 (DOI 10.2139/ssrn.1345420): https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1345420
   - Search snippets say it was posted 24 February 2009. The Crossref record was created 28 December 2011.
3. Manuscript "POW Working January 2012 MS Forthcoming.pdf" on Pontiff's Google Drive: https://drive.google.com/file/d/152qwaCLDge1N0P4V5ZKFdM6uqSPc4kqF/view

The article mentions results "reported in previous versions" (main_article_raw.txt line ~1834). Those versions are most likely items 1 and 2.

## Limitations

- Bot verification blocked the INFORMS site search and the SSRN page. Neither was bypassed.
- WebFetch automatically cached the AEA working-paper PDF in the session tool-results folder (sha256 ff6ca22a...c71c). It was not opened and not copied into the study.
- Mendeley Data's own search API ignores queries, so coverage of that repository relies on DataCite.
- Google Scholar versions were not checked.
- The project venv Python cannot load ssl because the Homebrew openssl@3 dylib is missing. HTTPS requests were made with curl instead.
