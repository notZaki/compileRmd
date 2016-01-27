# compileRmd

An R-Script for compiling RMarkdown documents with support for numbered equations, figures, tables and their cross-references. `compileRmd` exports to PDF (via LaTeX), Microsoft Word and HTML while using syntax that should be familiar to a typical LaTeX user.

An example is provided in the `inst/example` folder, where:  
The input RMarkdown file is: [example.Rmd](inst/example/example.Rmd)  
The html output is: [example.html](inst/example/example.html)  
The docx output is: [example.docx](inst/example/example.docx?raw=true)  
The pdf outpit is: [example.pdf](inst/example/example.pdf?raw=true)  

## Motivation and Purpose

I prefer writing documents using [RMarkdown](http://rmarkdown.rstudio.com/) which is a combination [R](http://www.r-project.org/), [knitr](http://yihui.name/knitr/), [Pandoc](http://pandoc.org/) and [Markdown](http://daringfireball.net/projects/markdown/).

Some of my reasons for using RMarkdown include:

- it exports to multiple formats, which keeps the people I work with happy. In particular:
    + *LaTeX* - for publication or for when a pdf is desired
    + *MS Word* - for collaborators who like 'track-changes', or for when LaTeX isn't accepted
    + *HTML* - for myself (I use it for previewing), for sharing online or for interactive reports (with [RCharts](https://github.com/ramnathv/rCharts) and [Shiny](http://shiny.rstudio.com/))
- its syntax is arguably easier to read/write compared to LaTeX
- it produces dynamic documents - analysis can be carried by code within a document instead of copy/pasting results
    + This also means that some elements, such as a plots and table, will change automatically if input (raw data) changes

However, there are some features which RMarkdown currently lacks. In particular, there is no native method for automatically numbering figures and tables or for cross-referencing figures and tables.  

Three possible ways (there could be more) around these limitations is by:

1. using LaTeX commands for labelling and cross-referencing [[1](https://github.com/chiakaivalya/thesis-markdown-pandoc), [2](https://github.com/tompollard/phd_thesis_markdown), [3](http://linguisticmystic.com/2015/03/04/how-to-write-a-dissertation-in-latex-using-markdown/)]  
2. using R to do the counting and cross-referencing [[4](http://rmflight.github.io/posts/2012/10/papersinRmd.html), [5](http://gforge.se/2014/01/fast-track-publishing-using-knitr-part-iii/), [6](https://github.com/humburg/reproducible-reports)]

The problem with option 1 is that LaTeX commands only work well if the final output is LaTeX. By using option 1, we have to sacrifice the ability to go from RMarkdown to non-TeX formats.  
Option 2 works well for non-TeX output formats, but the syntax requires some getting used to, and it hardcodes the LaTeX output.
i.e. the .tex source file might literally say 'Figure 1' in a caption.  

Ideally, we should pick an option based on the output format, and this is where `compileRmd` comes in.
Instead of worrying about which option to use, we can pretend that we're always using option 1 and use LaTeX commands.
If we need to output to a format that is **not** LaTeX, then `compileRmd` will convert everything so that it resembles option 2's syntax instead.
This task is carried out by a hilariously ugly script which heavily relies on regular expressions.

I have been using this script for over a year for multiple writing tasks (e.g. abstracts, MSC thesis) and it seems to do the job.
Others might find this to be useful, so I've wrapped the script into an R package that should, hopefully, be easy to use.

## Installation

This is an R package, so you'll need [R](http://www.r-project.org/).  
While an IDE isn't required, I'd still recommend grabbing [RStudio](http://www.rstudio.com/) as well.  
If you plan on producing LaTeX output, then you'll need an appropriate LaTeX engine installed. One way of obtaining it is through [TeX Live](https://www.tug.org/texlive/).

This script requires some pre-requisite and suggested packages which can be installed by entering the following in the R console:
```
requiredPackages <- c('devtools','knitr','rmarkdown','pander','ggplot2','Cairo','stringr','cowplot')
install.packages(requiredPackages)
```

Then, you can install `compileRmd` by entering the following in the R console:
```
devtools::install_github('notZaki/compileRmd')
```

## Description

### Features and Syntax

The syntax in this section will work for LaTeX/PDF, MS Word and HTML output. Most of it should be familiar to LaTeX users.
I won't go over the basics of Markdown syntax since there's already many excellent guides on that. See the full details of [RMarkdown features](http://rmarkdown.rstudio.com/authoring_pandoc_markdown.html) for more information.  

**Citations**  
In order to use citation, a .bib file will be needed. This can be specified in the function call, or in the YAML header.  
To cite something, use `\cite{}` with the appropriate reference key in the brackets.  
RMarkdown also supports [pandoc's citations](http://pandoc.org/README.html#citations) which could also be used. However, this might hard-code the citations in the LaTeX document (although there are ways around this by using pandoc flags such as `--biblatex` or `--natbib`).

**Equations**  
Numbered equations are possible if they are wrapped in `$#...#$`.
A label is mandatory on the first line. Here's an example:
```
$# \label{eq:yourLabel}
f(x) = ax^3 \cdot \sqrt{\beta x)}
#$
```
To reference the numbered equation, just type `\ref{eq:yourLabel}`.


**Figures**  
If an image is saved locally, then it can be inserted by:
```
![This is the figure caption. \label{fig:yourLabel}](path/to/imageFile)
```
The figure can be referenced by `\ref{fig:yourLabel}`.
If a label is not included at the end of the caption, then the figure will not be numbered, but will still have a caption.  
There should be an empty line before and after the figure, otherwise it will be interpreted as an in-line figure and a caption will not be produced.  

**Tables**  
The process for tables is similar to figures. Use a `\label{tab:}` tag at the end of the caption, e.g.:
```
x    y
---  ---
 1    1
 2    4  
 3    9  
 4   16  

Table: This is the caption. \label{tab:yourLabel}
```
The table can be referenced by `\ref{tab:yourLabel}`.

**Short Captions**  
If you need short captions for figures and tables in the LaTeX output (for list of figures/tables) then that is also possible.
Use square brackets in the caption for the short caption.  
For a figure, the code will look like:
```
![[This is the short caption] This is the long caption. Very descriptive. \label{fig:yourLabel}](path/to/image)
```
For a table, the caption part of the code would be be:
```
Table: [Short caption for table] This is the long caption. \label{tab:yourLabel}
```
Please try not use square brackets inside a caption for anything that isn't a short caption, or else the script might get angry.

**Embedded Figures and Tables**  
An alternative way of including figures and table in RMarkdown is by directly outputting it from R code chunks inside the document. Take a look at `inst/example/example.Rmd` for more details.

### Usage

The previous part went over the syntax, but how do we produce the output?
This is done by calling the compileRmd() function which has the form:
```
compileRmd(file=NULL, format='html', yaml=NULL, bibFile=NULL, cslFile=NULL,
           texEngine=NULL, bibEngine=NULL)
```

compileRmd's inputs are:
- `file` - Path to RMarkdown file.
    + If no file is specified, then the most recently modified .Rmd file in the current work directory will be compiled
- `format` - Output format.
    + Choices are: `'md'`,`'html'`, `'htmlB'`, `'word'`, `'tex'`.
        * `'md'` - Markdown output
        * `'html'` - HTML output
        * `'htmlB'` - [knitrBootstrap](https://github.com/jimhester/knitrBootstrap) output (experimental)
        * `'word'` - Microsoft Word .docx output
        * `'tex'` - LaTeX output that will also produce a PDF
- `yaml` - Path to a file containing the YAML header.
    + If no file is specified, then the function will try to find a YAML file in current work directory
        * Depending on the output format, it will look for the files: `yaml_md.txt`, `yaml_html.txt`, `yaml_htmlB.txt`, `yaml_word.txt`, or `yaml_tex.txt`.
    + If no YAML file is found in current work directory, it will use the default YAML headers in the `inst/DefaultYAML` folder
    + If the input document already contains a YAML header, then use `yaml=''` to use it.
- `bibFile` - Path to .bib file for citations
    + This can also be specified in the yaml header.
- `cslFile` - Path to a .csl file for formatting citations
    + This can also be specified in the yaml header.
    + Has no effect if bibtex or biber are used (see the 'bibEngine' input below).
- `texEngine` - LaTeX engine for generating the pdf document
    + Choices depend on what the user has installed. Possible options might include: `'pdflatex'`,`'xelatex'`
    + If no input is provided, then only a .tex file will be produced. A residual pdf might still be produced, but it will likely be missing features.
- `bibEngine` - bib engine for generating citations for pdf
    + Choices: `'bibtex'`, `'biber'`
    + If no choice is supplied, then all citations will be converted from `\cite{authour}` to pandoc's `[@author]` format and will use pandoc's citeproc. If you don't want this, but also don't want to use any bib engine, then set `bibEngine=''`.

### Some Notes

It is recommended to:  
+ Set the working directory to where the RMarkdown file is located
    * This can be done by using `setwd(path/to/RmdFile/directory)` in R
    * In RStudio, you can also use the menu bar - `Session` > `Set Working Directory`
+ Enter the specific bibFile and cslFile into a YAML header .txt file for each format
    * This way, you won't have to specify the bibFile/cslFile in the function call
    * The YAML file can also include initializing code for format-specific behaviour

Using the above will cut down on the amount of parameters needed to call the function.
A well-defined YAML header file will allow you to compile an html document by simply running `compileRmd()`.

## Some limitations

- Only LaTeX, MS Word and HTML output is currently supported
- Only three kinds of labels are currently supported and they must follow the format of:
    + `\label{eq:yourLabel}` - for equations
    + `\label{fig:yourLabel}` - for figures
    + `\label{tab:yourLabel}` - for tables
- `compileRmd` is not able to recognize whether the user is inside a code block. This means that a `\ref{}` command written inside a code block will be converted to a cross-reference, when it should actually remain untouched.
- Centering of equations, figures and tables in Word
    + Figures, tables and numbered equations might not be centered automatically in Word output. They can be formatted manually from within Word.
- LaTeX commands in a figure/table caption require double backslashes
    + i.e. Instead of a caption that says: `This figure is a plot of \ref{tab:someTable}` you should instead type it as `This figure is a plot of \\ref{tab:someTable}` and that that should work!
- `compileRmd` creates temporary files while compiling. They get cleaned up at the end, but they might remain if an error occurs and execution is halted. This might be a concern because if you run the function without specifying the input file, it will grab the most recent file, which in this case would be a residual temporary file, and the results will not be good.

# Alternatives

- [pandoc-crossref](https://github.com/lierdakil/pandoc-crossref)
    + Has some nifty features such as generating list of tables/figures in non-TeX output format
- [scholdoc](https://github.com/timtylin/scholdoc)
- Packages such as [captioner](https://github.com/adletaw/captioner) or [kfigr](https://github.com/mkoohafkan/kfigr), and there are many more, that try implementing cross-referencing

# Acknowledgements

This wouldn't be possible without the wizardry that is [knitr](http://yihui.name/knitr/) and [Pandoc](http://pandoc.org/).  
The code for numbering the figures/tables is from [this tutorial](https://github.com/humburg/reproducible-reports). The idea to wrap equations in a div tag for html output is also from there.  
The CSS for the html output is based on the style sheet by user [ArcoMul](https://github.com/ArcoMul) which was obtained from [this markdown template for thesis writing](https://github.com/tompollard/phd_thesis_markdown).  
The .tex output requires some cleaning, and for this task, some code was adapted from [this guide](http://linguisticmystic.com/2015/03/04/how-to-write-a-dissertation-in-latex-using-markdown/)
