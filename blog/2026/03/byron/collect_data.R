#!/usr/bin/env Rscript
# Incremental data collection for Byron blog post.
# Saves each snapshot to an individual RDS file so progress is preserved
# across runs. Only queries time points that haven't been collected yet.
#
# Usage: Rscript collect_data.R
# Run multiple times until all snapshots are collected.

library(osmdata)
library(sf)
library(dplyr)

# --- Configuration ---
# Determine script directory
script_dir <- tryCatch(
  dirname(sys.frame(1)$ofile),
  error = function(e) getwd()
)
data_dir <- file.path(script_dir, "data")
dir.create(data_dir, showWarnings = FALSE)

sleep_between <- 15  # seconds between queries
query_timeout <- 300  # Overpass server-side timeout
retries <- 3
retry_wait <- 30

# --- Time points ---
time_points <- seq(
  from = as.POSIXct("2012-09-13T00:00:00Z", tz = "UTC"),
  to = Sys.time(),
  by = "6 months"
)

# Also collect current data (datetime = NULL)
# We'll represent "current" with a special label

# --- Helper: filename for a time point ---
snapshot_filename <- function(tp) {
  label <- format(tp, "%Y-%m-%dT%H-%M-%SZ")
  file.path(data_dir, paste0("snapshot_", label, ".rds"))
}

# --- Query function ---
query_burger_chains <- function(bbox, datetime = NULL, timeout = 300) {
  q <- bbox |>
    opq(datetime = datetime, timeout = timeout) |>
    add_osm_feature(
      key = "amenity",
      value = c("restaurant", "fast_food", "food_court", "bar", "cafe", "pub")
    ) |>
    add_osm_feature(
      key = "name",
      value = c("Byron", "Gourmet Burger Kitchen", "Five Guys",
                "Honest Burger", "GBK"),
      match_case = FALSE, value_exact = FALSE
    ) |>
    osmdata_sf()

  pts <- q$osm_points[!is.na(q$osm_points$name), ]

  pts |>
    dplyr::mutate(
      chain = dplyr::case_when(
        grepl("five guys", name, ignore.case = TRUE) ~ "Five Guys",
        grepl("gourmet burger kitchen|\\bgbk\\b", name, ignore.case = TRUE) ~ "GBK",
        grepl("honest burger", name, ignore.case = TRUE) ~ "Honest Burgers",
        grepl("byron", name, ignore.case = TRUE) ~ "Byron",
        TRUE ~ NA_character_
      )
    ) |>
    dplyr::filter(!is.na(chain))
}

# --- Also collect london_admin if missing ---
admin_file <- file.path(data_dir, "london_admin.rds")
london <- getbb("London, UK")

if (!file.exists(admin_file)) {
  message("Collecting London admin boundaries...")
  for (i in seq_len(retries)) {
    london_admin <- tryCatch({
      london |>
        opq(timeout = query_timeout) |>
        add_osm_feature(key = "admin_level", value = "8") |>
        osmdata_sf() |>
        with(osm_multipolygons)
    }, error = function(e) {
      message("  Attempt ", i, " failed: ", e$message)
      if (i < retries) { Sys.sleep(retry_wait); NULL } else { NULL }
    })
    if (!is.null(london_admin)) {
      saveRDS(london_admin, admin_file)
      message("  Saved london_admin.rds (", nrow(london_admin), " polygons)")
      break
    }
  }
  if (is.null(london_admin)) message("  WARNING: Could not collect london_admin")
  Sys.sleep(sleep_between)
} else {
  message("london_admin.rds already exists, skipping.")
}

# --- Collect current data if missing ---
current_file <- file.path(data_dir, "snapshot_current.rds")
if (!file.exists(current_file)) {
  message("Collecting current data...")
  for (i in seq_len(retries)) {
    current <- tryCatch(
      query_burger_chains(london, datetime = NULL, timeout = query_timeout),
      error = function(e) {
        message("  Attempt ", i, " failed: ", e$message)
        if (i < retries) { Sys.sleep(retry_wait); NULL } else { NULL }
      }
    )
    if (!is.null(current)) {
      current$snapshot_date <- Sys.time()
      saveRDS(current, current_file)
      message("  Saved snapshot_current.rds (", nrow(current), " rows)")
      break
    }
  }
  if (is.null(current)) message("  WARNING: Could not collect current data")
  Sys.sleep(sleep_between)
} else {
  message("snapshot_current.rds already exists, skipping.")
}

# --- Check which historical snapshots are missing ---
existing <- vapply(time_points, function(tp) file.exists(snapshot_filename(tp)), logical(1))
missing_tp <- time_points[!existing]

message("\n--- Status ---")
message("Total time points: ", length(time_points))
message("Already collected: ", sum(existing))
message("Missing: ", length(missing_tp))

if (length(missing_tp) == 0) {
  message("\nAll snapshots collected! You can now render the blog post.")

  # Combine all into a single all_data.rds
  message("Combining all snapshots into all_data.rds...")
  all_files <- list.files(data_dir, pattern = "^snapshot_.*\\.rds$", full.names = TRUE)
  all_data <- do.call(rbind, lapply(all_files, readRDS))
  saveRDS(all_data, file.path(data_dir, "all_data.rds"))
  message("Saved all_data.rds (", nrow(all_data), " total rows)")
} else {
  message("\nCollecting missing snapshots...\n")

  collected <- 0
  failed <- 0

  for (tp in missing_tp) {
    tp <- as.POSIXct(tp, origin = "1970-01-01", tz = "UTC")
    dt_str <- format(tp, "%Y-%m-%dT%H:%M:%SZ")
    fname <- snapshot_filename(tp)

    message("Querying: ", dt_str)
    Sys.sleep(sleep_between)

    result <- NULL
    for (i in seq_len(retries)) {
      result <- tryCatch(
        query_burger_chains(london, datetime = dt_str, timeout = query_timeout),
        error = function(e) {
          message("  Attempt ", i, " failed: ", e$message)
          if (i < retries) Sys.sleep(retry_wait)
          NULL
        }
      )
      if (!is.null(result)) break
    }

    if (!is.null(result) && nrow(result) > 0) {
      result$snapshot_date <- tp
      saveRDS(result, fname)
      collected <- collected + 1
      message("  Saved: ", nrow(result), " rows")
    } else if (!is.null(result) && nrow(result) == 0) {
      # Save empty result too so we don't re-query
      result$snapshot_date <- tp
      saveRDS(result, fname)
      collected <- collected + 1
      message("  Saved: 0 rows (no data for this date)")
    } else {
      failed <- failed + 1
      message("  FAILED after ", retries, " attempts, will retry on next run")
    }
  }

  message("\n--- Run complete ---")
  message("Collected: ", collected)
  message("Failed: ", failed)
  if (failed > 0) {
    message("Run this script again to retry failed snapshots.")
  }

  # If all are now collected, combine
  existing_now <- vapply(time_points, function(tp) file.exists(snapshot_filename(tp)), logical(1))
  if (all(existing_now)) {
    message("\nAll snapshots now collected! Combining into all_data.rds...")
    all_files <- list.files(data_dir, pattern = "^snapshot_.*\\.rds$", full.names = TRUE)
    all_data <- dplyr::bind_rows(lapply(all_files, readRDS))
    saveRDS(all_data, file.path(data_dir, "all_data.rds"))
    message("Saved all_data.rds (", nrow(all_data), " total rows)")
  }
}
