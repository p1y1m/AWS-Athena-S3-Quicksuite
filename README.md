# AWS Athena S3 Quicksuite – Panel Example

**Author: Pedro Yanez Melendez**  

This repository shows a small sample of the work I did with AWS Athena, S3 and QuickSight.  

Here I include one Athena SQL query and the graph that uses this query.

All the data shown in this sample is anonymized, and the names of tables, fields, charts, etc. have been replaced with fictitious ones.

## Background

In a larger project I documented and maintained two main dashboards:

1. Network quality indicators  
2. Customer issues and incidents  

Each dashboard has several sheets and graphs.  
Each graph is linked to a specific query. I first wrote and saved the query in Athena, and then I saved it again as a dataset in QuickSight (SPICE) and used that dataset in the graph.

The goal of the documentation was to transfer knowledge so the team is not dependent on one person, and so that other people can follow and modify the panels in case of vacations or absence.

This repository only shows one of those queries as a small example.

## Files in this repo

- `athena_query.sql` – Athena SQL query used for one “customer issues and incidents” graph.  
  It classifies each service unit by week according to how many “pains” (a summary of several conditions) it has: 0, 1, 2 or 3.

## What the Athena query does

The query runs on a service quality table per device stored in S3 and queried through Athena.

It does the following:

### 1. Builds three partial queries

**Q1 – Signal quality condition**

- Uses data for all wireless devices (excludes wired and special-purpose devices).  
- Calculates the minimum weekly signal value per device and service unit.  
- Flags a service unit when there are 6 or more devices below a defined signal threshold in the week.  

**Q2 – Throughput condition on band A**

- Uses records where the connection is on band A and excludes special-purpose devices.  
- Calculates the minimum weekly downlink rate per device and service unit.  
- Flags a service unit when there are 6 or more devices below a defined throughput threshold.  

**Q3 – Throughput condition on band B**

- Uses records where the connection is on band B and excludes special-purpose devices.  
- Calculates the minimum weekly downlink rate per device and service unit.  
- Flags a service unit when there are 6 or more devices below a higher throughput threshold.  

These criteria are the same ones used for the “pain” graph in this example.

### 2. Combines the three pains per service unit

- Builds a unified list of (week, service unit) keys using the three partial queries.  
- Joins the results to have, for each service unit and week:
  - Pain flag for signal quality  
  - Pain flag for throughput on band A  
  - Pain flag for throughput on band B  

### 3. Counts number of pains per service unit

- For each service unit and week, it counts how many of the three flags are in “pain” state.

### 4. Aggregates by week for the final graph

- For each week, it sums:
  - Service units with 0 pains  
  - Service units with 1 pain  
  - Service units with 2 pains  
  - Service units with 3 pains  
- This final result is what I used to build a weekly graph (stacked bars) that shows how the distribution of pains changes by week.

## How I used Athena, S3 and QuickSight

The flow I used was:

1. Service quality data is stored in S3 and is available in Athena as external tables.  
2. In Athena I wrote and saved the queries, with clear names for each graph.  
3. In QuickSight I created datasets based on those saved queries (SPICE), and then created the graphs using those datasets.  

## Other queries and graphs in the project

Besides this pain graph, I also documented other queries and graphs, for example:

- Volumetry (number of service units and connected devices).  
- Traffic (per-device and per-unit traffic, upload and download rates).  
- Connection quality per device and by band.  
- Latency metrics for devices and service units.  
- A second pain graph for a different type of service, with its own rules.

These other queries and graphs are not included in this repository, but they are part of the same family of panels.

## Data validation

I documented and executed several validations to check that the Athena queries were correct.

For the pain panel:

- I used different queries to count unique service units with and without certain filters (for example wired or special-purpose devices) and checked that the totals matched.  
- I repeated the same calculations in Excel for a reference week, using formulas and pivot tables, and confirmed that the number of pains in Excel and in Athena was exactly the same.  
- I kept the manual work in hidden sheets inside the validation Excel file.  

For the network quality panel:

- I checked that the values in the graphs created from Athena were the same as the values in an existing presentation that used Excel as the source.

## Panel access

I also documented who had access to the panels.

- The panels have a defined list of people with access, either as Viewer or Co-owner.  
- Some users are only Viewers because they do not have the right profile to be Co-owners.

This helps to keep control of who can see and who can edit the dashboards.
