#' Search Europe PMC publication database
#'
#' @description This is the main function to search
#' Europe PMC RESTful Web Service (\url{http://europepmc.org/RestfulWebService})
#'
#' @seealso \url{http://europepmc.org/Help}
#'
#' @param query character, search query. For more information on how to
#'   build a search query, see \url{http://europepmc.org/Help}
#' @param output character, what kind of output should be returned. One of 'parsed', 'id_list'
#'   or 'raw' As default, parsed key metadata will be returned as data.frame.
#'   'id_list' returns a list of IDs and sources.
#'   Use 'raw' to get full metadata as list. Please be aware that these lists
#'   can become very large.
#' @param limit integer, limit the number of records you wish to retrieve.
#'   By default, 100 are returned.
#' @param synonym logical, synonym search. If TRUE, synonym terms from MeSH
#'  terminology and the UniProt synonym list are queried, too. Disabled by
#'  default.
#' @param sort character, sort results by order (\code{asc}, \code{desc}) and
#'  sort field (e.g. \code{CITED}, \code{P_PDATE}), seperated with a blank.
#'  For example, sort results  by times cited in descending order:
#'  \code{sort = 'CITED desc'}.
#' @param verbose	logical, print some information on what is going on.
#' @return tibble
#' @examples \dontrun{
#' #Search articles for 'Gabi-Kat'
#' my.data <- epmc_search(query='Gabi-Kat')
#'
#' #Get article metadata by DOI
#' my.data <- epmc_search(query = 'DOI:10.1007/bf00197367')
#'
#' #Get article metadata by PubMed ID (PMID)
#' my.data <- epmc_search(query = 'EXT_ID:22246381')
#'
#' #Get only PLOS Genetics article with EMBL database references
#' my.data <- epmc_search(query = 'ISSN:1553-7404 HAS_EMBL:y')
#' #Limit search to 250 PLOS Genetics articles
#' my.data <- epmc_search(query = 'ISSN:1553-7404', limit = 250)
#'
#' # include mesh and uniprot synonyms in search
#' my.data <- epmc_search(query = 'aspirin', synonym = TRUE)
#'
#' # get 100 most cited atricles from PLOS ONE
#' epmc_search(query = 'ISSN:	1932-6203', sort = 'CITED desc')
#'
#' # print number of records found
#' attr(my.data, "hit_count")
#'
#' # change output
#'
#' }
#' @export
epmc_search <- function(query = NULL,
                        output = 'parsed',
                        synonym = FALSE,
                        verbose = TRUE,
                        limit = 100,
                        sort = NULL) {
  query <- transform_query(query)
  stopifnot(is.logical(c(verbose, synonym)))
  stopifnot(is.numeric(limit))
  # get the correct hit count when mesh and uniprot synonyms are also searched
  synonym <- ifelse(synonym == FALSE, "false", "true")
  page_token <- "*"
  if (!output == "raw")
    results <- dplyr::data_frame()
  else
    results <- NULL
  out <-
    epmc_search_(
      query = query,
      limit = limit,
      output = output,
      synonym = synonym,
      verbose = verbose,
      page_token = page_token,
      sort = sort
    )
  res_chunks <- chunks(limit = limit)
  # super hacky to control limit, better approach using pageSize param needed
  hits <- epmc_hits(query, synonym = synonym)
  if (hits == 0)
    stop("There are no results matching your query")
  limit <- as.integer(limit)
  limit <- ifelse(hits <= limit, hits, limit)
  # let's loop over until page max is reached, or until cursor marks are identical
  i <- 0
  while (i < res_chunks$page_max) {
    out <-
      epmc_search_(
        query = query,
        limit = limit,
        output = output,
        synonym = synonym,
        verbose = verbose,
        page_token = page_token,
        sort = sort
      )
    if (page_token == out$next_cursor)
      break
    i <- i + 1
    if (verbose == TRUE)
      message(paste("Retrieving result page", i))
    page_token <- out$next_cursor
    if (output == "raw") {
      results <- c(results, out$results)
    } else {
      results <- dplyr::bind_rows(results, out$results)
    }
  }
  # again, approach needed to use param pageSize instead
  if (output == "raw") {
    md <- results[1:limit]
  } else {
    md <- results[1:limit,]
  }
  # return hit counts(thanks to @cstubben)
  attr(md, "hit_count") <- hits
  return(md)
}

#' Get one page of results when searching Europe PubMed Central
#'
#' In general, use \code{\link{epmc_search}} instead. It calls this function, calling all
#' pages within the defined limit.
#'
#' @param query character, search query. For more information on how to
#'   build a search query, see \url{http://europepmc.org/Help}
#' @param output character, what kind of output should be returned. One of 'parsed', 'id_list'
#'   or 'raw' As default, parsed key metadata will be returned as data.frame.
#'   'id_list returns a list of IDs and sources.
#'   Use 'raw' to get full metadata as list. Please be aware that these lists
#'   can become very large.
#' @param limit integer, limit the number of records you wish to retrieve.
#'   By default, 25 are returned.
#' @param synonym logical, synonym search. If TRUE, synonym terms from MeSH
#'  terminology and the UniProt synonym list are queried, too. Disabled by
#'  default.
#' @param sort character, sort results by order (\code{asc}, \code{desc}) and
#'  sort field (e.g. \code{CITED}, \code{P_PDATE}), seperated with a blank.
#'  For example, sort results  by times cited in descending order:
#'  \code{sort = 'CITED desc'}.
#' @param page_token cursor marking the page
#'
#' @param ... further params from \code{\link{epmc_search}}
#'
#' @export
#'
#' @seealso \link{epmc_search}
epmc_search_ <-
  function(query = NULL,
           limit = 100,
           output = "parsed",
           synonym = FALSE,
           page_token = NULL,
           sort = NULL,
           ...) {
    # control limit
    limit <- as.integer(limit)
    page_size <- ifelse(batch_size() <= limit, batch_size(), limit)
    # choose output
    if (!output %in% c("id_list", "parsed", "raw"))
      stop("'output' must be one of 'parsed', 'id_list'. 'raw'",
           call. = FALSE)
    result_types <- c("id_list" = "idlist",
                      "parsed" = "lite",
                      "raw" = "core")
    resulttype <- result_types[[output]]
    # build query
    args <-
      list(
        query = query,
        format = "json",
        synonym = synonym,
        resulttype = resulttype,
        pageSize = page_size,
        cursorMark = page_token,
        sort = val_args(sort)
      )
    # call API
    out <-
      rebi_GET(path = paste0(rest_path(), "/search"), query = args)
    # remove nested lists from resulting data.frame, get these infos with epmc_details
    if (!resulttype == "core") {
      md <- out$resultList$result
      if (length(md) == 0) {
        md <- dplyr::data_frame()
      } else {
        md <- md %>%
          dplyr::select_if(Negate(is.list)) %>%
          as_data_frame()
      }
    } else {
      out <- jsonlite::fromJSON(out, simplifyDataFrame = FALSE)
      md <- out$resultList$result
    }
    list(next_cursor = out$nextCursorMark, results = md)
  }

#' encode param for API call
#' @param x API parameter
#' @noRd
val_args <- function(x) {
  if (!is.null(x))
    utils::URLencode(x)
  NULL
}
