# Readme

To use the example, try the following in the R console:
```
library(compileRmd)
exampleDir <- system.file('example',package='compileRmd')
setwd(exampleDir)

# Compile html
compileRmd()

# Compile docx
compileRmd(format='word')

# Compile PDF
compileRmd(format='tex', texEngine='pdflatex', bibEngine='bibtex')
```
