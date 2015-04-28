#' Rescale the column of a data frame to between 0 and 1
rescaleDf <- function(df){
  output.list <- lapply(df, function(col){
    x.max <- max(col)
    x.min <- min(col)
    new.vals <- (col - x.min)/(x.max - x.min)
    list(new.vals = new.vals, x.min = x.min, x.max = x.max)
  })
  new.df <- do.call("cbind", lapply(output.list, function(item) item$new.vals))
  new.df <- as.data.frame(new.df)
  min.max.list <- lapply(output.list, function(item){
    c(item$x.min, item$x.max)
  })
  list(df = new.df, min.max = min.max.list)
}


formatVertexList <- function(output){
  if(is.list(output)){
    if(length(output) > 1){
      output.list.item <- as.data.frame(do.call("cbind", lapply(output, head)))
      if(ncol(output.list.item) == vcount(g)){
        names(output.list.item) <- V(g)
      }
      output <- list(output.list.item)
    } else {
      output <- list(head(unlist(output)))
    }
  }
  output
}

#' Pull fitted values from a graph into a data frame
#' 
#' @param g A fitted graph
#' @return a data frame containing fitted values
#' @export
getFitted <- function(g){
  vertices_of_interest <- V(g)[!(type %in% "intercept")]
  vertices_of_interest$output.signal %>% #Pull everything but the intercepts
    {do.call("rbind", .)} %>% t %>% as.data.frame %>% `names<-`(vertices_of_interest$name) # Put into a data frme
}

#' Summarize the values of an igraph neural net model 
examineFFGraph <- function(g, formatVertexAttr = formatVertexList){
  examineGraph(g, formatVertexAttr=formatVertexAttr)
}

#' The Logistic Function and Its Derivative
#' @export
logistic <- function(z) 1 / (1 + exp(-z))
#' @rdname logistic
logistic.prime <- function(z) exp(-z)/(1+exp(-z))^2

#' Checks the validity of a numeric vertex attribute
#' 
#' @example
#' checkNumericError(unlist(V(g)[type == "output"]$observed))
isValid <- function(item){
  valid <- TRUE
  if(any(is.na(item))) valid <- FALSE
  if(any(is.infinite(item))) valid <- FALSE
  if(length(item) == 0) valid <- FALSE
  valid
}

#' Calculate the Values of Vertices in Neural Network Model
#' 
#' For a given vertex, input and the output signals are calculated.
#' 
#' @param g, the graph model
#' @param v.index, the index of a vertex
#' @return an updated graph model
calculateVals <- function(g, v.index){
  v <- V(g)[v.index]
  v.parents <- iparents(g, v)
  if(length(v.parents) == 0) stop("Attempting apply activation function
                                  to a node without parents.")
  parent.val.mat <- do.call("cbind", V(g)[v.parents]$output.signal)
  weights <- matrix(E(g)[to(v)]$weight, ncol=1)
  linear.combination <- as.numeric(parent.val.mat %*% weights)
  V(g)[v]$input.signal <- list(linear.combination)
  V(g)[v]$f.prime.input <- list(g$activation.prime(linear.combination))
  output <- g$activation(linear.combination)
  V(g)[v]$output.signal <- list(output)
  V(g)[v]$output.signal %>% unlist %>% {!isValid(.)} %>% `if`(stop("Error in output for vertex ", v.index))
  g
}

#' Reset Model Attributes
#' 
#' Resets the attributes of a model, after some of the attributes have been updated.
#' @param g a model
#' @return A model with updated attributes reset to FALSE
resetUpdateAttributes <- function(g){
  V(g)$updated <- FALSE
  E(g)$updated <- FALSE
  V(g)[type %in% c("input", "intercept")]$updated <- TRUE
  g
}

#' Add Nodes Corresponding to Biases
#' 
#' If intercepts (biases) already exist in the graph, no intercepts are added.
addInterceptNodes <- function(g){
  # If intercepts already exist, do nothing
  if("intercept" %in% V(g)$type) return(g)
  non.input.nodes <- V(g)[inDegree(g, V(g)) != 0]
  g.new <- g
  for(v in non.input.nodes){
    v <- as.numeric(v)
    intercept.name <- paste("int", v, sep=".")
    g.new <- g.new + intercept.name #Add the intercept to the graph
    g.new <- initializeVertexVectors(g.new, intercept.name) #Having added the intercept, give it the correct properties
    V(g.new)[intercept.name]$type <- "intercept" #Label the intercept as 'intercept'
    V(g.new)[intercept.name]$output.signal <- list(rep(1, g$n)) #Give the value of 1
    g.new <- g.new + igraph::edge(intercept.name, V(g)[v]$name)
  }
  g.new
}

#' Initialize numerically-valued vertex attributes
#' 
#' For a given vertex, vertex attibutes that take a numeric vector as a value are 
#' initialized with a placeholder. Specifically, the vertex attributes are;
#' \itemize{
#'  \item{input.signal}{The vector of linear combination of values from the parent nodes}
#'  \item{output.signal}{The output of the activation function applied to input.signal}
#'  \item{f.prime.input}{The derivative of the activation function applied to the input.signal}
#'  \item{observed}{Observed values in the data.  Not present for hidden and input nodes.}
#'  }
#' All of these are initialized with NA values
#' 
#' @param g graph model
#' @param v.index vertex index
#' @return and igraph object where the above attributes are initialized to the value \code{list(rep(NA, g$n))}
initializeVertexVectors <- function(g, v.index){
  na.placeholder <- list(rep(NA, g$n)) 
  V(g)[v.index]$input.signal <- na.placeholder
  V(g)[v.index]$f.prime.input <- na.placeholder
  V(g)[v.index]$output.signal <- na.placeholder
  V(g)[v.index]$observed <- na.placeholder
  g
}

#' Simulating starting weights
initializeWeights <- function(g){  
  if(any(is.infinite(g$min.max.constraints)) || is.null(g$min.max.contraints)) {
    E(g)$weight <- rnorm(ecount(g), sd = 3)
  } else {
    E(g)$weight <- runif(ecount(g), min = g$min.max.constraints[1], max = g$min.max.constraints[2])
  }
  g
}


#' Primes a Graph Object for Fitting a Neural Network Model
#' @param g igraph object with vertices corresponding to input nodes, output nodes, and 
#' hidden nodes.
#' @param input.table data frame of the input values
#' @param output.table data frame of the output values
#' @param activation function, the desired activation function
#' @param activation.prime, the Derivative of the desired activation function
#' @param min.max.constraints (optional) numeric containing the limiting range of the estimates
#' 
#' @return A graph with all the attributes needed to fit the neural network model.
#' 
#' @export
initializeGraph <- function(g, input.table, output.table, activation=logistic, 
                            activation.prime=logistic.prime, min.max.constraints=NULL){
  if(length(
    intersect(list.graph.attributes(g), 
                      c("activation", "activation.prime", 
                              "min.max.constraints", "n"))
            ) > 1 ){
    stop("This graph structure seems to have already been updated.")
  }
  g$activation <- activation
  g$activation.prime <- activation.prime
  if(!is.null(min.max.constraints)) names(min.max.constraints) <- c("min", "max")
  g$min.max.constraints <- min.max.constraints 
  g$n <- nrow(output.table)
  if(!is.null(V(g)$type)) stop("Graph vertices already have a type attribute.")
  V(g)$type <- "middle"
  V(g)[names(input.table)]$type <- "input"
  V(g)[names(output.table)]$type <- "output"
  for(v in V(g)){
    g <- initializeVertexVectors(g, v)
  }
  g <- addInterceptNodes(g)
  g <- resetUpdateAttributes(g)
  for(input in names(input.table)){
    V(g)[input]$output.signal <- list(input.table[, input])
  }
  V(g)$observed <- NA
  for(output in names(output.table)){
    V(g)[output]$observed <- list(output.table[, output])
  }
  #Reinitialize names
  g <- nameEdges(g)
  #initialize weights
  g <- initializeWeights(g)
  ##V(g)$intercept <- runif(vcount(g))
  ##V(g)[type == "input"]$intercept <- NA
  g <- updateVertices(g, getDeterminers = iparents, callback = calculateVals)
  g
}



#' A Simple Matrix Multiplication to Calculate Linear Inputs
getLinearCombination <- function(weights, model.mat) as.numeric(model.mat %*% weights)

#' Calculates the Derivative of a Node's Output Signal w.r.t a Weight.
#' @param g a model
#' @param v vertex index 
#' @param e edge index
#' @return a vector corresponding to the Derivative
doChainRule <- function(g, v, e){
  e.src <- getEdgeVertex(g, e, "from")
  if(v == e.src) stop("The chainrule has gone back too far, v: ", v, " e: ", e)
  e.trg <- getEdgeVertex(g, e, "to")
  if(!(e.trg %in%  v || isBDownstreamOfA(g, a = e.trg, b = v))){
    stop("You've attempted to find the gradient of a node's output
         w.r.t an edge weight that that does not affect that output. v: ", v, " e: ", e)  
  }
  f.prime.input <- unlist(V(g)[v]$f.prime.input)
  #Next check that the edge is not an incoming edge to v
  if(e.trg == v){
    e.src <- getEdgeVertex(g, e, "from")
    output <- unlist(V(g)[e.src]$output.signal) * f.prime.input
  }else{
    connected.nodes <- V(g)[getConnectingNodes(g, e.trg, v)]
    varying.parents <- V(g)[intersect(iparents(g, v), connected.nodes)]
    parent.names <- paste(varying.parents)
    v.parents.chain.rule.result <- matrix(NA, nrow = g$n, ncol = length(varying.parents), 
                                          dimnames = list(NULL, parent.names))
    for(v.parent.index in varying.parents){
      v.parent <- V(g)[v.parent.index]
      v.parents.chain.rule.result[, paste(v.parent)] <- doChainRule(g, v.parent, e)
    }
    output <- rowSums(
      apply(v.parents.chain.rule.result, 2, function(parent.result){
        parent.result * f.prime.input
      })
    )
  }
  #message("Completed chainrule calculation for node ", v, " w.r.t edge ", e)
  if(!is.numeric(output)){
    stop("v: ", 
         V(g)[v], 
         ", e: ", 
         E(g)[e], " output: ", 
         paste(round(head(output), 2), collapse=" "), 
         ", fpi: ", 
         paste(round(head(f.prime.input), 2), collapse=" ")
    )
  }
  output
  }

plotPath <- function(g, src, trg){
  if(!(trg %in% getDownstreamNodes(g, src))) {
    h.list <- list(nodes = node.names, col = "red")  
    plot.args <- list(highlight = h.list, main = paste(node.names, collapse = " to "))
    igraphGraphvizPlot(g, plot.args = plot.args)
    message("Plotting Error: Target is not downstream of the source.")
  }else{
    v.set <- getConnectingNodes(g, src, trg)
    e.set <- E(g)[v.set %->% v.set]
    h.edges <- get.edgelist(g)[e.set, ]
    node.names <- V(g)[c(src, trg)]
    h.list <- list(nodes = node.names, arcs = h.edges, col = "red")
    plot.args <- list(highlight = h.list, main = paste(node.names, collapse = " to "))
    igraphGraphvizPlot(g, plot.args = plot.args)
  }
}

# g <- generateMultiConnectedDAG(10)
# v1 <- sample(V(g), 1)
# v2 <- sample(getDownstreamNodes(g, v1), 1)
# v1;v2
# plotPath(g, v1, v2)
getPrediction <- function(g, v, weights){
  #message("Prediction function call: candidate weights being propagated forward.")
  prediction.graph <- g
  E(prediction.graph)[to(v)]$weight <- weights
  prediction.graph <- updateVertices(prediction.graph, getDeterminers = iparents, callback = calculateVals)
  prediction <- unlist(V(prediction.graph)[type == "output"]$output.signal)
  if(!isValid(prediction)) stop("An error occured in predicting vertex ", v)
  prediction
}

getLoss <- function(g){
  observed <- unlist(V(g)[type=="output"]$observed)
  prediction <- unlist(V(g)[type=="output"]$output.signal)
  .5 * sum( (observed - prediction) ^ 2)
}

getLossFunction <- function(g, v){
  #Creating a temporary graph where new weights for v are added, the values are propagated forward.
  #And a new prediction is generated
  lossFunction <- function(weights){
    prediction <- getPrediction(g, v, weights)
    observed <- unlist(V(g)[type=="output"]$observed)
    .5 * sum( (observed - prediction) ^ 2)
  }
  lossFunction
} 

getGradientFunction <- function(g, v){
  # This closure returns a function that computes the gradient of all the weights 
  # on the incoming edges of a node v.  Unlike in multi-layer perceptrons where the
  # weights at each level are optimized together, here the weights for each incoming 
  # edge for each node are optimized together
  # 1) Get the parents and parent matrices
  v.incoming.edges <- E(g)[to(v)]
  edge.names <- paste(v.incoming.edges)
  incoming.edge.count <- length(v.incoming.edges)
  output.node <- V(g)[type=="output"]
  gradientFunction <- function(weights){
    #Calculates the gradient for a set of weights using the doChainRule function
    prediction <- getPrediction(g, v, weights)
    observed <- unlist(output.node$observed)
    loss.function.derivative <- -1 * (observed - prediction)
    chain.rule.output <- matrix(NA, nrow = g$n, ncol = incoming.edge.count, dimnames = list(NULL, edge.names))
    for(e.index in v.incoming.edges){
      e <- E(g)[e.index]
      chain.rule.output[, paste(e)] <- doChainRule(g, output.node, e)
    }
    gradient.output <- colSums(
      apply(chain.rule.output, 2, function(chain.rule.result){
        loss.function.derivative * chain.rule.result
      })
    )
    gradient.output    
  }
  gradientFunction
}

getOptimizationFunction <- function(g, lossFunction, getGradient){
  if(!is.null(g$min.max.constraints)){
    lower <- rep(g$min.max.constraints["min"], length(weights))
    upper <- rep(g$min.max.constraints["max"], length(weights))
    names(lower) <- names(upper) <- NULL
    optimFunction <- function(weights){
      optim(weights, fn = lossFunction, gr = getGradient, method="L-BFGS-B",
            lower=lower, upper=upper)$par
    }
  }else{
    optimFunction <- function(weights){
      optim(weights, fn = lossFunction, gr = getGradient, method="BFGS")$par
    }
  }
  optimFunction
}

fitWeightsForNode <- function(g, v){
  v <- V(g)[v]
  lossFunction <- getLossFunction(g, v)
  getGradient <- getGradientFunction(g, v)
  weights.initial <- E(g)[to(v)]$weight
  optimizer <- getOptimizationFunction(g, lossFunction, getGradient)
  weights.updated <- optimizer(weights.initial)
  E(g)[to(v)]$weight <- weights.updated
  g
}

fitWeightsForEdgeTarget <- function(g, e){
  old_weight <- E(g)[e]$weight
  edge.target <- get.edgelist(g)[e, 2]
  message("Fitting for edge ", E(g)[e]$name)
  g <- fitWeightsForNode(g, edge.target)
  new_weight <- E(g)[e]$weight
  if(new_weight == old_weight) message(E(g)[e]$name, ': Old weight = ', old_weight, ', New Weight = ', new_weight)
  E(g)[e]$updated <- TRUE
  g
}

fitInitializedNetwork <- function(g, epsilon, max.iter, verbose=F){
  e <- 2 * getLoss(g)  / g$n  #Multiply * 2 because of .5 coefficient in loss function. Devide by n to get mean error loss
  i <- 1
  test <- TRUE
  while(test){
    print(i)
    g <- resetUpdateAttributes(g)
    if(verbose){
      g <- updateEdges(g, getDeterminers = getDependentEdges, callback = fitWeightsForEdgeTarget)
    }else{
      g <- suppressMessages(updateEdges(g, getDeterminers = getDependentEdges, callback = fitWeightsForEdgeTarget))
    }
    g <- updateVertices(g, getDeterminers = iparents, callback = calculateVals)
    e.new <- 2 *  getLoss(g) / g$n  
    message("Error: ", round(e.new, 3), "\n")
    message("Weights: ", paste(round(E(g)$weight[1:3], 3), collapse =", "), "\n")
    test <- (e - e.new) > epsilon || i < max.iter
    i <- i + 1
    e <- e.new
  }
  g
}

#' Fit a Neural Network on a Graph Structure
#' 
#' @export
fitNetwork <- function(g, input.table, output.table, epsilon=.05, max.iter=3, 
                       activation=logistic, activation.prime=logistic.prime, 
                       min.max.constraints = NULL, verbose=F){
  g <- initializeGraph(g, input.table, output.table, 
                       activation = activation, 
                       activation.prime = activation.prime,
                       min.max.constraints = min.max.constraints)
  g <- fitInitializedNetwork(g, epsilon, max.iter, verbose)
}

#' Add new data to fitted model in order to do prediction
newDataUpdate <- function(g, input.table){
  for(input in names(input.table)){
    V(g)[input]$output.signal <- list(input.table[, input])
  }
  g <- updateVertices(g, getDeterminers = iparents, callback = calculateVals)
}

#' Get a data frame of output signals   
getDF <- function(g){
  output <- do.call(data.frame, V(g)[type != "intercept"]$output.signal)
  names(output) <- paste(V(g)[type != "intercept"])
  output
}

getDependentEdges <- function(g, e){
  #Determine the edges in g whose weights impact the 
  #optimization of the weight of edge e 
  e <- E(g)[ e]
  v_trg_name <- get.edgelist(g)[e, 2]
  v.trg <- V(g)[v_trg_name] %>% as.numeric
  output.v <- V(g)[type == "output"] %>% as.numeric
  dependent.edges <- NULL
  if(!(v.trg == output.v)){
    if(output.v %in% ichildren(g, v.trg)) {
      dependent.edges <- E(g)[v.trg %->% output.v]
    }else{
      dependent.edges <- getConnectingEdges(g, v.trg, output.v)
    }
  }
  dependent.edges
}