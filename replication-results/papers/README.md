# Papers

This folder contains no PDFs. The articles and supplements are copyrighted, so they are not redistributed here.

[catalog.json](catalog.json) lists the six public-source articles studied, with the DOI to get each one from its publisher and the SHA-256 of the exact file the readers used. [supplements/catalog.json](supplements/catalog.json) does the same for the one supplement used (Thébaud 2015, S1).

| Study | Article | DOI |
| --- | --- | --- |
| delaney1996 | Delaney and Huselid (1996), *Academy of Management Journal* | 10.5465/256718 |
| deephouse1999 | Deephouse (1999), *Strategic Management Journal* | 10.1002/(SICI)1097-0266(199902)20:2<147::AID-SMJ11>3.0.CO;2-Q |
| holderness2012 | Holderness and Pontiff (2012), *Management Science* | 10.1287/mnsc.1120.1532 |
| lehman2011 | Lehman, Hahn, Ramanujam and Alge (2011), *Organization Science* | 10.1287/orsc.1100.0626 |
| thebaud2015 | Thébaud (2015), *Administrative Science Quarterly* | 10.1177/0001839215591627 |
| twenge2010 | Twenge, Campbell, Hoffman and Lance (2010), *Journal of Management* | 10.1177/0149206309352246 |

In the original run, this folder held a library of 1,197 article PDFs and 114 supplement PDFs. The paths in the catalogs and in each study's `STUDY.json` (for example `papers/journal_collection/SMJ/SMJ_1999_Deephouse.pdf`) show where each file sat. To rerun a study, put the publisher's PDF at that path and check its SHA-256 against the catalog. A different PDF version will have a different hash.

Berry and Hildreth (2025), *Organization Science*, DOI 10.1287/orsc.2023.18003, is an additional deposited-data case outside this library, its catalog and the 277-candidate screening pool. Its article and Online Appendix sat in `studies/berry2025/packet/`, with their hashes in that study's [STUDY.json](../studies/berry2025/STUDY.json).

Nagaraj (2021), *Management Science*, DOI 10.1287/mnsc.2020.3764, is also outside this catalog and the 277-candidate screening pool. Its article belongs at `studies/nagaraj2021/packet/nagaraj2021.pdf`; its deposited appendix belongs at `studies/nagaraj2021/data/raw/osf_a47e9/writing/appendix.pdf`. The [study README](../studies/nagaraj2021/README.md), [STUDY.json](../studies/nagaraj2021/STUDY.json) and [publication inventory](../studies/nagaraj2021/packet/publication_packet.json) document versions and hashes. These source documents are not included in the export.
