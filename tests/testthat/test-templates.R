
context("templates for commmonly used signal graph models")
library(dplyr, quietly = TRUE)
source("test_dir/test_helpers.R")

test_that("get_gate with all outputs works as expected", {
  gates <- c("AND", "OR", "NAND", "NOR", "XOR", "XNOR") 
  g <- get_gate(layers = c(2, 3))
  V(g)[is.observed]$name %>%
    setdiff(c(gates, "I1", "I2")) %>%
    {length(.) == 0 } %>%
    expect_true  
})

test_that("get_gate with partial outputs works as expected", {
  gates <- c("AND", "NAND", "XNOR") 
  g <- get_gate(outputs = gates, layers = c(2, 3))
  V(g)[is.observed]$name %>%
    setdiff(c(gates, "I1", "I2")) %>%
    {length(.) == 0 } %>%
    expect_true  
})

test_that("get_gate produces the expected outputs on 2 input system", {  
  # This is what the output data frame should look like
  logic_gates <- expand.grid(list(I1 = c(0, 1), I2 = c(0, 1))) %>% 
    {dplyr::mutate(., AND = (I1 * I2 == 1) * 1, #dplyr has to be prefixed here for the code to work for some reason.
           OR = (I1 + I2 > 0) * 1 ,
           NAND = (!AND) * 1,
           NOR = (!OR) * 1,
           XOR = (I1 + I2 == 1) * 1, 
           XNOR = (I1 == I2) * 1)}
  # So recreate this data frame from the function output and compare
  get_gate(layers = c(3, 3)) %>% 
    recover_design %>% #The outputs in the design should be the same as the logic_gates table
    identical(logic_gates) %>%
    expect_true
})

test_that("get_gate replicates a hand made version", {
  system <- expand.grid(list(I1 = c(0, 1), I2 = c(0, 1))) %>% 
    mutate(AND = (I1 * I2 == 1) * 1)
  g1 <- get_gate("AND", c(3, 2))
  g2 <- mlp_graph(c("I1", "I2"), "AND", c(3, 2)) %>% #Use a 2 layer MLP
    initializeGraph(select(system, I1, I2, AND), fixed = c("I1", "I2"))
  expect_equal(V(g1)$name, V(g2)$name)
})

context("Simulating a system and data from the system")

# When simulating a system, we want a gold standard that is identical 
# to a fitted model in terms of data structure.  The simulation simulates
# weights, generates fitted 'output.signal' values based on those weights, then 
# enters values for observed values from those weight.  

data(mapk_g)
test_that("sim_system produces observed values that are the same as the 
          'fitted' (output.signal) values.", {
            list(g1 = sim_system(10, 100), 
                 g2 = sim_system(10, 100, mapk_g)) %>%
              lapply(function(g){
                observed <- recover_design(g) 
                fitted <- get_fitted(g)[, names(observed)] 
                expect_identical(observed, fitted)
              })
          })

test_that("we can add Gaussian error to get realistic data.", {
  g <- sim_system(10, 100)
  fixed <- V(g)[is.fixed]
  observed_and_random <- intersect(V(g)[is.observed], V(g)[is.random])
  unrandom_data <- recover_design(g) 
  random_data <- unrandom_data %>%
    add_error(V(g)[observed_and_random]$name, 1000)
  for(v in names(unrandom_data)){
    if(v %in% fixed$name){
      expect_equal(rep(0, nrow(unrandom_data)), abs(unrandom_data[,v] - random_data[, v]))
    }else{
      expect_true(mean(unrandom_data[,v] - random_data[, v]) != 0)
    }
  }  
})

test_that("we can simulate a dataset with error", {
  # Data simulation pulls the fitted values, adds error, and returns the observed values. 
  list(g1 = sim_system(10, 50), 
       g2 = sim_system(10, 50, mapk_g)) %>%
    lapply(function(g){
      observed_random <- intersect(V(g)[is.observed], V(g)[is.random])
      set.seed(1)
      sim_data <- sim_data_from_system(g, 1000)
      expect_true(all(names(sim_data) %in% V(g)[is.observed]$name))
      set.seed(1)
      test_data <- recover_design(g) %>%
        add_error(V(g)[observed_random]$name, factor = 1000)
      expect_identical(sim_data, test_data)
    })
})

test_that("sim_system enables control of the proportion of edge weights that are 0", {
  skip("skipped")
  edge_sparcity <- function(g) ecount(g) /(vcount(g) * vcount(g) - 1) 
  1:50 %>%# number of graphs to generate
    lapply(function(i) sim_system(vcount(mapk_g), n = 10, input_g = mapk_g)) %>%
    lapply(function(item) induced_subgraph(item, V(item)[!is.bias])) %>%
    lapply(edge_sparcity) %>%
    unlist %>%
    mean %>%
    expect_equal(edge_sparcity(mapk_g), tolerance = .1)
})