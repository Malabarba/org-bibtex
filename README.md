org-bibtex
==========

Simple example of combining a .bib file with org-mode.
Uusally there are a lot more entries in the file, I trimmed it down to make it easier.

I have a set of functions which pull both the pdf file and the bibtex entry when I provide a URL, and then inserts a headline into the papers.org.bib file. This headline contains a subheadline with  the bibtex entry, and has a few useful properties (like the Author, the file location (for easy opening) and the journal).

This gives me a lot of power for visualising the entry list. I can make a sparse list with according to Author, I can make quick-and-simple searches or complex-regexp searches, and (thanks to the notes I write inside the headlines) I always have quick information about the paper available. 

This also allows me to keep well organized on when I want to read my papers. Since each papers is a headline, I can just assign it as TODO (meanning I want to read it eventually), or I can schedule it (meanning I it will show up on my agenda view at the time I want).
