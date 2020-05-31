
epmc_datalinks <- function(ext_id = NULL,
                          data_src = "med",
                          limit = 100,
                          verbose = TRUE) {
  # validate input
  val_input(ext_id, data_src, limit, verbose)
  # build request
  path <- mk_path(data_src, ext_id, req_method = "datalinks")
  # how many records are found?
  if (!is.null(path))
    doc <- rebi_GET(path = path,
                    query =list(format = "json")
    )
  hit_count <- doc$hitCount
  if (hit_count == 0) {
    message("Sorry, no links available")
    out <- NULL
  } else {
    # provide info
    msg(hit_count = hit_count,
        limit = limit,
        verbose = verbose)
    # request records and parse them
    if (hit_count >= limit) {
      req <-
        rebi_GET(path = path,
                 query = list(format = "json", pageSize = limit, resulttype = "core"))
      #out <- req[["dataLinkList"]]
     out <- req
    } else {
      query <-
        make_path(hit_count = hit_count,
                  limit = limit)
      out <- lapply(query, function(x) {
        req <-
          rebi_GET(path = path,
                   query = list(format = "json", pageSize = limit, resulttype = "core"))
      })
    }
    # return hit count as attribute
    attr(out, "hit_count") <- hit_count
  }
  out
}
