#' @title Compiles RMarkdown file
#'
#' @description Compiles Rmarkdown file to pdf, html, or word.

#' @param file RMarkdown file.
#' @param format Output format. Choices are: 'md', 'html', 'htmlB', 'word', 'tex'.
#' @param yaml (Optional) Template file.
#'   This is path to a .txt file containing YAML header.
#'   If input Rmd file already contains YAML header, then set this to ''.
#'   Otherwise, a default YAML header will be used depending on the output format.
#' @param bibFile (Optional) Bibtex file to use for citations.
#' @param cslFile (Optional) CSL file to use for citation styling.
#' @param texEngine (Optional) The latex command to use for tex output (e.g. 'pdflatex')
#' @param bibEngine (Optional) Choices are either 'biber' or 'bibtex'.
#'
#' @export

compileRmd <- function(file = NULL, # RMarkdown file
                       format = 'html', # Options: 'html','htmlB', 'word','tex'
                       yaml = NULL, # Path to .txt YAML header file
                       bibFile = NULL, # Path to .bib file
                       cslFile = NULL, # Path to .csl file
                       texEngine = NULL, # Command for calling latex. For latex only
                       bibEngine = NULL # For Latex only. Options: 'biber', 'bibtex'
                       )
{

  # If no file is entered, then use the most recently modified .Rmd file in current directory
  if (is.null(file)) {
    rmdFiles <- list.files(pattern = '\\.Rmd')
    numFiles <- length(rmdFiles)
    if (numFiles < 1) return('No file to compile')
    latestTime <- as.POSIXct("1970-01-01 00:00:00", tz = "UTC")
    latestInd <- 0
    for (i in 1:numFiles) {
      curTime <- file.mtime(rmdFiles[i])
      if (curTime > latestTime) {
        latestTime <- curTime
        latestInd <- i
      }
    }
    file <- rmdFiles[latestInd]
    cat('No file entered. Compiling last modified file:', file, '\n')
  }

  # Make sure chosen output format is supported
  supportedFormats = c('md','html','htmlB','word','tex')
  if (is.element(format,supportedFormats) == FALSE) {
    cat('The input: format =', shQuote(format), 'is not supported\n')
    cat('Supported engines are:', toString(supportedFormats), '\n')
    return()
  }

  # Make sure chosen bibEngine is supported
  supportedEngines = c('', 'biber', 'bibtex')
  if ( (!is.null(bibEngine)) && (is.element(bibEngine,supportedEngines) == FALSE) ) {
    cat('The input: bibEngine =', bibEngine, 'is not supported\n')
    cat('Supported engines are:', toString(supportedEngines[-1]), '\n')
    cat('No bib engine will be used.\n')
    bibEngine <- NULL
    warning('bibEngine not found. No bib engine was used.')
  }

  # Initialize the cross-references ------------------------------------------
  # This is verbatim code from http://galahad.well.ox.ac.uk/repro/
  # except the options are slightly changed
  figRef <- local({
    tag <- numeric()
    created <- logical()
    used <- logical()
    function(label, caption, prefix = options("figcap.prefix"),
             sep = options("figcap.sep"), prefix.highlight = options("figcap.prefix.highlight")) {
      i <- which(names(tag) == label)
      if (length(i) == 0) {
        i <- length(tag) + 1
        tag <<- c(tag, i)
        names(tag)[length(tag)] <<-
          label
        used <<- c(used, FALSE)
        names(used)[length(used)] <<-
          label
        created <<-
          c(created, FALSE)
        names(created)[length(created)] <<-
          label
      }
      if (!missing(caption)) {
        created[label] <<- TRUE
        paste0(prefix.highlight, prefix, " ", i, sep, prefix.highlight,
               " ", caption)
      } else {
        used[label] <<- TRUE
        paste(tag[label])
      }
    }
  })

  tabRef <- local({
    tag <- numeric()
    created <- logical()
    used <- logical()
    function(label, caption, prefix = options("tabcap.prefix"),
             sep = options("tabcap.sep"), prefix.highlight = options("tabcap.prefix.highlight")) {
      i <- which(names(tag) == label)
      if (length(i) == 0) {
        i <- length(tag) + 1
        tag <<- c(tag, i)
        names(tag)[length(tag)] <<-
          label
        used <<- c(used, FALSE)
        names(used)[length(used)] <<-
          label
        created <<-
          c(created, FALSE)
        names(created)[length(created)] <<-
          label
      }
      if (!missing(caption)) {
        created[label] <<- TRUE
        paste0(prefix.highlight, prefix, " ", i, sep, prefix.highlight,
               " ", caption)
      } else {
        used[label] <<- TRUE
        paste(tag[label])
      }
    }
  })

  options(
    tabcap.prefix = "Table", tabcap.sep = ":", tabcap.prefix.highlight = "**"
  )
  options(
    figcap.prefix = "Figure", figcap.sep = ":", figcap.prefix.highlight = "**"
  )
  # End of cross-reference initialization -------------------------------------

  # Get path and file name about input file
  filePath <- dirname(file)
  fileName <- tools::file_path_sans_ext(basename(file)) # File name without extension

  # Change work directory to filePath for convenience
  # At the end of this function, we will revert the work directory back to originalWd
  originalWd <- getwd()
  cat('Setting path directory to', filePath, '\n')
  setwd(filePath)

  # Pre-Processing ==============================================
  cat('Pre-processing input file.\n')
  rawText <- readLines(file)
  tmpFile <- paste0(fileName,'_tmp.Rmd')

  # Get YAML header information
  useYaml <- T    # Are we using an external YAML header? Assume yes, initially.
  if (is.null(yaml)) {
    # If no YAML header is supplied,
    # then search in current directory, and then search package directory
    defaultHeaderFile <- paste('yaml_',format,'.txt', sep='')
    if (file.exists(defaultHeaderFile)) {
      yamlHeader <- readLines(defaultHeaderFile)
    } else {
      yamlHeader <- getYamlHeader(format)
    }
  } else if (yaml == '') {
    # In this case, YAML header already exists in the input file
    useYaml <- F
  } else {
    # Otherwise, load the YAMl header from user-supplied file
    yamlHeader <- readLines(yaml)
  }

  # DISABLED FOR NO PARTICULAR REASON
  # # If no bib file is provided, try searching for it in input document
  # # i.e. look for a \bibliography{} section
  # bibLine <- grep('^\\\\bibliography\\{(.*)\\}', rawText)
  # if (is.null(bibFile) && length(bibLine) > 0) {
  #   bibFile <- gsub('\\\\bibliography\\{(.*?)\\}', '\\1', mdText[bibLine])
  #   bibFile <- paste0(bibFile,'.bib')
  # }

  # Enter bib and csl file into external yaml headers
  # and combine to make single temporary file
  if (useYaml == T) {
    if (!is.null(bibFile)) {
      yamlHeader <- gsub('`varBib`', bibFile, yamlHeader)
  	}
  	if (!is.null(cslFile)) {
        yamlHeader <- gsub('`varCSL`', cslFile, yamlHeader)
  	}
  	grbgLines <- c(grep('`varBib`',yamlHeader),grep('`varCSL`',yamlHeader))
  	if (length(grbgLines)>0) {
  		yamlHeader <- yamlHeader[-grbgLines]
  	}
    # For tex output, we need to grab bibFile name from YAML header if input was NULL
    if (is.null(bibFile) && format=='tex') {
      yamlBibLine <- grep('bibliography', yamlHeader)
      if (length(yamlBibLine)>0) bibFile <- gsub('^(.*?)\\[(.*?)\\](.*?)', '\\2', yamlHeader[yamlBibLine])
    }
    cat(yamlHeader, rawText, file = tmpFile,sep = '\n')
  } else {file.copy(file, tmpFile)}

  # Knit the temporary markdown file, and then delete that temporary input file
  mdFile <- file.path(filePath, paste0(fileName, '.md'))
  knitr::knit(input = tmpFile, output = mdFile)
  cat('Knitr output:', mdFile, '.\n')
  file.remove(tmpFile)

  # Now we process knitr's output
  cat('Pre-processing markdown file.\n')
  mdText <- readLines(mdFile)
  mdText <- gsub('\\% !TEX root.*$', '', mdText) # I use this line for LaTeX Tools

  # If output is not latex, or no bibEngine is supplied, then use pandoc's citation
  # Have to convert \cite{authout1,...,authorN} to [@author1,...,@authorN] format
  if (format != 'tex' || is.null(bibEngine)) {
    mdText <- gsub('\\\\cite\\{(.*?)\\}', '\\[@\\1\\]', mdText)
    while (length(grep('\\[@(.*?),(.*)\\]', mdText)) > 0) {
      mdText <- gsub('\\[@(.*?),(.*)\\]', '\\[@\\1;@\\2\\]', mdText) # For multi-citations
    }
  }

  # Format-specific formatting
  if (format == 'tex') {
    # If output is latex, then we need to convert $#...#$ to equation environment
    mdText <- gsub('^\\$# (.*)', '\\\\begin\\{equation} \\1', mdText)
    mdText <- gsub('^#\\$', '\\\\end\\{equation}', mdText)

    # We need to replace double backslashes by single backslashes because regex
    # and R eat backslashes (it's an escape character) for non-tex output.
    # For tex output, we don't need double backslashes, so we replace them by single backslash.
    # Replace double backslashes by single backslash for figure captions
    figLines <- grep('\\\\label\\{fig', mdText)
    if (length(figLines) > 0) {
      for (i in figLines) {
      	# For each backslash, R sees double, so '\' is '\\' in R.
      	# For each backslash, regex also sees double.
      	# We're using regex through R, so we have to quadruple them
      	# i.e., '\' --(to R)--> '\\' --(to regex)--> '\\\\'
      	# So, to detect a doubleslash ('\\'), we need to find 8 backslashes,
      	# and we replace it with 4 backslashes to get single backslash as output.
        slashLines <- grep('\\\\\\\\',mdText[i])
        while(length(slashLines)>0) {
        	mdText[i] <- gsub('\\\\\\\\','\\\\',mdText[i])
        	slashLines <- grep('\\\\\\\\',mdText[i])
        }
      }
    }
    # Replace double backslashes by single backslash for tabel captions
    tabLines <- grep('\\\\label\\{tab', mdText)
    if (length(tabLines) > 0) {
      for (i in tabLines) {
        slashLines <- grep('\\\\\\\\',mdText[i])
        while(length(slashLines)>0) {
        	mdText[i] <- gsub('\\\\\\\\','\\\\',mdText[i])
        	slashLines <- grep('\\\\\\\\',mdText[i])
        }
      }
    }

  } else {
    # If output is not latex, then... we have a lot of work to do

    # Need to convert '$#...#$' to '(@label) $...$' notation,
    # and it needs a div class wrapped around it
    mdText <- gsub('^\\$# \\\\label\\{eq:(.*)\\}', '(@eq\\1) ', mdText)
    eqLines <- grep('^\\(@eq.*\\)', mdText) # Where equations start
    endLines <- grep('^#\\$', mdText) # Where equations end
    # If single equation spans multiple lines, we have to melt it into one line
    # and remove the lines which the equation previously occupied (grbgLines)
    grbgLines <- vector(mode="numeric", length=0)
    # Go through all the equation lines and convert their syntax
    if (length(eqLines) > 0) {
      for (i in 1:length(eqLines)) {
        curStart <- eqLines[i]
        # Find where the current equation line ends
        curEnd <- endLines[min(which((endLines>eqLines[i]) == TRUE))]
        curLine <- paste0(mdText[curStart],'$')
        grbgLinesTmp <- vector(mode="numeric", length=0)
        # Melt the lines into a single line
        for (lineInd in (curStart+1):(curEnd-1)) {
        	curLine <- paste0(curLine,mdText[lineInd])
        	mdText[lineInd] <- ''
        	grbgLinesTmp <- c(grbgLinesTmp,lineInd)
        }
        curLine <- paste0(curLine,'$')
        # Wrap a div tag (only for html but should be unnoticeable in Word output)
        divStart <- gsub('^\\(@(.*?)\\).*', '<div id=\\"\\1\\" class=\\"equation\\">', curLine)
        mdText[curStart:(curStart+1)] = c(divStart, curLine)
        mdText[curEnd] = '</div>'
        # Note down the unnecessary lines (but we keep the first line because equation spans two lines)
        grbgLines <- c(grbgLines,grbgLinesTmp[-1])
      }
    }
    if (length(grbgLines)>0){mdText <- mdText[-grbgLines]} # Remove unnecessary lines

    # Replace \ref{eq:label} for equations with @eqlabel
    mdText <- gsub('\\\\ref\\{eq:(.*?)\\}', '@eq\\1', mdText)

    # Replace figure text using figref
    figLines <- grep('\\\\label\\{fig', mdText)
    if (length(figLines) > 0) {
      for (i in figLines) {
        # Assign label and number to each figure
        # Can't pass gsub directly to figref because it treats '\\2' as the label.
        # Need to store the label as a variable first.
        figLabel <- gsub('!\\[(.*?)\\\\label\\{fig:(.*?)\\}(.*)$','\\2',mdText[i])
        figLabel <- paste0('fig',figLabel)
        figText <- stringr::str_trim(gsub('!\\[(.*?)\\\\label\\{fig:(.*?)\\}(.*)$','\\1',mdText[i]))
        figText <-  gsub('^\\[(.*?)\\](.*?)','\\2', figText)  # Discard short caption, if it exists
        mdText[i] <- gsub('\\[(.*?)\\\\label\\{fig:(.*?)\\}', paste0('[',figRef(figLabel,figText)), mdText[i])
      }
    }

    # Replace references to figure by the appropriate figure number
    figLines <- grep('\\\\ref\\{fig', mdText)
    while (length(figLines) > 0) {
      # While loop is used because single line can have multiple figure references
      for (i in figLines) {
        figLabel <- sub('^(.*)\\\\ref\\{fig:(.*?)\\}(.*)$', '\\2', mdText[i])
        figLabel <- paste0('fig',figLabel)
        mdText[i] <- sub('\\\\ref\\{fig:(.*?)\\}',figRef(figLabel),mdText[i])
      }
      figLines <- grep('\\\\ref\\{fig', mdText)
    }

    # Replace table text using tabRef (similar to previous code for figRef)
    tabLines <- grep('\\\\label\\{tab', mdText)
    if (length(tabLines) > 0) {
      for (i in tabLines) {
        tabLabel <- gsub('^(.*?)\\\\label\\{tab:(.*?)\\}(.*)$','\\2',mdText[i])
        tabLabel <- paste0('tab',tabLabel)
        tabText <-  stringr::str_trim(gsub('^Table:(.*?)\\\\label\\{tab:(.*?)\\}(.*)$','\\1',mdText[i]))
        tabText <-  gsub('^\\[(.*?)\\](.*?)','\\2', tabText)
        newTabLine <- paste0('Table: ', tabRef(tabLabel,tabText))
        mdText[i] <- gsub('^Table:(.*?)\\\\label\\{tab:(.*?)\\}', newTabLine, mdText[i])
      }
    }

    # Replace cross-references to tables with apropriate table number
    tabLines <- grep('\\\\ref\\{tab', mdText)
    while (length(tabLines) > 0) {
      for (i in tabLines) {
        tabLabel <- sub('^(.*)\\\\ref\\{tab:(.*?)\\}(.*)$', '\\2', mdText[i])
        tabLabel <- paste0('tab',tabLabel)
        mdText[i] <- sub('\\\\ref\\{tab:(.*?)\\}',tabRef(tabLabel),mdText[i])
      }
      tabLines <- grep('\\\\ref\\{tab', mdText)
    }

    # If there are latex-specific commands, they will not render in word/html
    # Unwrap the commands here:
    mdText <- gsub('\\\\uline\\{(.*)\\}', '\\1', mdText) # Disable underlining

    # Word doesn't like \big and variants?
    if (format == 'word') {
      mdText <- gsub('\\\\big\\{(.*?)\\}', '\\1', mdText)
      mdText <- gsub('\\\\Big\\{(.*?)\\}', '\\1', mdText)
      mdText <- gsub('\\\\bigg\\{(.*?)\\}', '\\1', mdText)
      mdText <- gsub('\\\\Bigg\\{(.*?)\\}', '\\1', mdText)
    }
  }

  # Overwrite original markdown file with our processed markdown file
  cat(mdText, file = mdFile,sep = '\n')

  # Conversion ===============================================
  cat('Converting markdown to output format.\n')

  if (format == 'md') {
    # Our work is already done
    setwd(originalWd)
    return(mdFile)
  } else if (format == 'html') {
    # Render using rmarkdown
    rmarkdown::render(mdFile)
    htmlFile <- file.path(filePath, paste0(fileName, '.html'))
    setwd(originalWd)
    return(htmlFile)
  } else if (format == 'htmlB') {
    # Have to convert to Rmd before rendering knitrBootstrap format
    rmdFileTmp <- file.path(filePath, paste0(fileName, '_tmp.Rmd'))
    htmlFileTmp <- file.path(filePath, paste0(fileName, '_tmp.html'))
    htmlFile <- file.path(filePath, paste0(fileName, '.html'))
    file.copy(mdFile, rmdFileTmp)
    rmarkdown::render(rmdFileTmp)
    # Images don't get recognized by magnific popup? This fixes it for me.
    htmlText <- readLines(htmlFileTmp)
    htmlText <- gsub("(<img src[^<]+/>)","<a href='#' class='thumbnail'>\\1</a>", htmlText)
    # Save html file and remove temporary files
    cat(htmlText,file = htmlFile,sep = "\n")
    file.remove(rmdFileTmp)
    file.remove(htmlFileTmp)
    setwd(originalWd)
    return(htmlFile)
  } else if (format == 'word') {
    # Similar steps as html code above
    rmarkdown::render(mdFile)
    docFile <- file.path(filePath, paste0(fileName, '.docx'))
    setwd(originalWd)
    return(docFile)
  } else {
    # Latex output
    pdfFile <- file.path(filePath, paste0(fileName, '.pdf'))
    # Render the markdown file to start things off
    rmarkdown::render(mdFile)

    # Now we have to process the tex file a bit
    texFile <- file.path(filePath, paste0(fileName, '.tex'))
    texText <- readLines(texFile)
    cat('Post-Processing .tex file.\n')

    # Note down where the document ends
    endDocLine <- grep('\\\\end\\{document\\}', texText)

    # Add bibiliography lines for bibEngine if there is a bibFile
    # The 'titleKiller' is there to prevent LaTeX from making a new title,
    # becase there should already be a bibiliography title in the input document
    if (!is.null(bibFile) && !is.null(bibEngine)) {
      titleKiller <- paste0('\\ifdefined\\chapter  \n',
                            '\\renewcommand{\\chapter}[2]{}  \n',
                            '\\else  \n',
                            '\\renewcommand{\\section}[2]{}  \n',
                            '\\fi  \n'
                            )
      bibData <- paste0('\\bibliography{', bibFile,'}\n')
      bibData <- paste0(titleKiller, bibData, '\\bibliographystyle{plain}')
      texText <- c(texText[1:endDocLine-1], bibData, texText[-1:-(endDocLine-1)])
    }

    # Clean up tex file
    # First four greps are based on Will Styler's code (see readme.md)
    # Can't remember why I made the last two greps. Clearing empty lines around equations, maybe?
    unwantedLines <- c(
        grep('\\\\itemsep1pt\\\\parskip0pt\\\\parsep0pt', texText),
        grep('\\\\def\\\\labelenumi\\{\\\\arabic\\{enumi\\}.\\}', texText),
        grep('\\\\def\\\\labelenumi\\{\\(\\\\arabic\\{enumi\\}\\)\\}', texText),
        grep('\\\\def\\\\labelenumi\\{\\\\alph\\{enumi\\}.\\}', texText),
        grep('^\r?\n?\\\\begin\\{equation\\}', texText) - 1,
        grep('^\\\\end\\{equation\\}\r?\n?', texText) + 1)
    if (length(unwantedLines) > 0) {
      texText <- texText[-unwantedLines]
    }

    # Fix the format for short captions
    # The input will be: \caption{[Short caption] Long caption}
    #           we want: \caption[Short caption]{Long caption}
    # This would have been easy, but pandoc auto-wraps the text in the text file
    # so we might have short and long captions spanning multiple lines.
    # This code assumes that the short caption doesn't span more than 5 lines.
    capLines <- grep('\\\\caption\\{', texText)
    startTok <- grep('\\{\\[\\}', texText)
    endTok <- grep('\\{\\]\\}', texText)
    capLines <- capLines[capLines %in% startTok] # Only process captions which include short captions
    grbgLines <- 0
    for (i in capLines) {
      shortCap = ''
      if (i %in% startTok && i %in% endTok) {
        # If short caption is all on a single line, then great!
        shortCap <- gsub('\\\\caption\\{\\{\\[\\}(.*?)\\{\\]\\}.*', '\\1', texText[i])
        texText[i] <- gsub('\\\\caption\\{\\{\\[\\}(.*)\\{\\]\\}(.*)', paste0('\\\\caption\\[', shortCap, '\\]\\{\\2'), texText[i])
      } else {
        # If short caption spans multiple lines, then keep reading lines untill we see the endToken.
        shortCap <- gsub('\\\\caption\\{\\{\\[\\}(.*)', '\\1', texText[i])
        k <- 1
        # Give up after 5 lines. This will produce an error in latex, but will give the user a chance to manually fix the mistake.
        # Without this 5 line limit, this script might destory the entire tex document!
        while ( k<5 && !((i+k) %in% endTok) ) {
          grbgLines <- c(grbgLines, i+k)
          shortCap <- c(shortCap, texText[i+k])
          k <- k+1
        }
        # For the last line (where short caption ends) only grab the short caption part
        shortCap <- c(shortCap, gsub('^(.*)\\{\\]\\}.*', '\\1', texText[i+k]))
        # ... and also delete the short caption part from the long caption
        texText[i+k] <- gsub('^(.*)\\{\\]\\}(.*)', '\\2', texText[i+k])
        # Combine the short captions together, and place it using the correct syntax
        shortCap <- paste(shortCap, collapse=' ')
        texText[i] <- gsub('\\\\caption\\{\\{\\[\\}.*', paste0('\\\\caption\\[', shortCap, '\\]\\{'), texText[i])
      }
    }
    # Delete all lines that were originally occupied by short captions
    if (length(grbgLines)>1) {
      grbgLines <- grbgLines[-1]
      texText <- texText[-grbgLines]
    }
    grbgLines <- NULL # This line of the code is unnecessary

    cat(texText,file = texFile,sep = '\n') # Save the cleaned tex file

    # If no texEngine provided, then stop here
    if (is.null(texEngine)) {
      setwd(originalWd)
      return(texFile)
    }
    # Otherwise, run latex
    cat('Running latex command:\n')
    latexCmd <- paste(texEngine, texFile)
    cat(latexCmd, '\n')
    system(latexCmd)

    # Run bib reference manager, if it is provided
    if (is.null(bibEngine) || bibEngine=='') {
      cat('No bib engine was selected.\n')
    } else {
      bibCmd <- paste(bibEngine, fileName)
      cat('Running', bibEngine, '\n')
      system(bibCmd)
      cat('Running', texEngine, 'again. \n')
      system(latexCmd)
    }

    # Victory lap
    cat('One final run of', texEngine, '\n')
    system(latexCmd)
    setwd(originalWd)
    return(pdfFile)
  }
}
