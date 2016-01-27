#' @title Get Default YAML headers
#'
#' @description Returns default YAML headers depending on the format.
#'
#' @param format Output format. Choices are: 'html', 'htmlB', 'word', 'tex'.

getYamlHeader <- function(format = NULL){
  yamlFile <- paste0('yaml_', format, '.txt')
  yamlFullPath <- system.file('DefaultYAML', yamlFile, package='compileRmd')
  yamlHeader <- readLines(yamlFullPath)
  if (format == 'html') {
  	styleFile <- system.file('DefaultYAML','style.css', package='compileRmd')
  	yamlHeader <- gsub('`varStyle`', styleFile, yamlHeader)
  }
  return(yamlHeader)
}
