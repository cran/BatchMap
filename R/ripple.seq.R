########################################################################
##                                                                     #
## Package: BatchMap                                                     #
##                                                                     #
## File: ripple.seq.R                                                  #
## Contains: ripple.seq                                                #
##                                                                     #
## Written by Gabriel Rodrigues Alves Margarido                        #
## copyright (c) 2009, Gabriel R A Margarido                           #
##                                                                     #
## First version: 02/27/2009                                           #
## License: GNU General Public License version 2 (June, 1991) or later #
##                                                                     #
########################################################################

##' Compares and displays plausible alternative orders for a given linkage
##' group
##'
##' For a given sequence of ordered markers, computes the multipoint likelihood
##' of alternative orders, by shuffling subsets (windows) of markers within the
##' sequence. For each position of the window, all possible \eqn{(ws)!}{(ws)!}
##' orders are compared.
##'
##' Large values for the window size make computations very slow, specially if
##' there are many partially informative markers.
##'
##' @param input.seq an object of class \code{sequence} with a
##'     predefined order.
##' @param ws an integer specifying the length of the window size
##'     (defaults to 4).
##' @param LOD threshold for the LOD-Score, so that alternative orders
##'     with LOD less then or equal to this threshold will be
##'     displayed.
##' @param tol tolerance for the C routine, i.e., the value used to
##'     evaluate convergence.
##' @return This function does not return any value; it just produces
##'     text output to suggest alternative orders.
##' @author Gabriel R A Margarido, \email{gramarga@@gmail.com} and
##'     Marcelo Mollinari, \email{mmollina@@usp.br}
##' @seealso \code{\link[BatchMap]{make.seq}},
##'     \code{\link[BatchMap]{compare}}, \code{\link[BatchMap]{try.seq}}
##'     and \code{\link[BatchMap]{order.seq}}.
##' @references Broman, K. W., Wu, H., Churchill, G., Sen, S., Yandell, B.
##' (2008) \emph{qtl: Tools for analyzing QTL experiments} R package version
##' 1.09-43
##'
##' Jiang, C. and Zeng, Z.-B. (1997). Mapping quantitative trait loci with
##' dominant and missing markers in various crosses from two inbred lines.
##' \emph{Genetica} 101: 47-58.
##'
##' Lander, E. S., Green, P., Abrahamson, J., Barlow, A., Daly, M. J., Lincoln,
##' S. E. and Newburg, L. (1987) MAPMAKER: An interactive computer package for
##' constructing primary genetic linkage maps of experimental and natural
##' populations. \emph{Genomics} 1: 174-181.
##'
##' Mollinari, M., Margarido, G. R. A., Vencovsky, R. and Garcia, A. A. F.
##' (2009) Evaluation of algorithms used to order markers on genetics maps.
##' \emph{Heredity} 103: 494-502.
##'
##' Wu, R., Ma, C.-X., Painter, I. and Zeng, Z.-B. (2002a) Simultaneous maximum
##' likelihood estimation of linkage and linkage phases in outcrossing species.
##' \emph{Theoretical Population Biology} 61: 349-363.
##'
##' Wu, R., Ma, C.-X., Wu, S. S. and Zeng, Z.-B. (2002b). Linkage mapping of
##' sex-specific differences. \emph{Genetical Research} 79: 85-96
##' @keywords utilities
##' @examples
##'
##' \dontrun{
##'  #Outcross example
##'   data(example.out)
##'   twopt <- rf.2pts(example.out)
##'   markers <- make.seq(twopt,c(27,16,20,4,19,21,23,9,24,29))
##'   markers.map <- map(markers)
##'   ripple.seq(markers.map)
##' }
##'
ripple.seq<-function(input.seq,ws=4,LOD=3,tol=10E-2) {
    ## checking for correct objects
    if(!any(class(input.seq)=="sequence")) {
      stop(deparse(substitute(input.seq)),
           " is not an object of class 'sequence'")
    }
    if(ws < 2) stop("ws must be greater than or equal to 2")
    if(ws > 5) warning("WARNING: this operation may take a VERY long time\n\n")

    len <- length(input.seq$seq.num)
    ## computations unnecessary in this case
    if (len <= ws) stop("Length of sequence ",
                        deparse(substitute(input.seq)),
                        " is smaller than ws. You can use the ",
                        "compare function instead")

    ## allocate variables
    rf.init <- rep(NA,len-1)
    phase <- rep(NA,len-1)
    tot <- prod(1:ws)
    best.ord.phase <- matrix(NA,tot,len-1)
    best.ord.like <- best.ord.LOD <- rep(-Inf,tot)
    all.data <- list()

    ## gather two-point information
    list.init <- phases(input.seq)

#### first position
    message(input.seq$seq.num[1:ws],"|",input.seq$seq.num[ws+1], "...", sep="-")

    ## create all possible alternative orders for the first subset
    all.ord <- t(apply(perm.tot(head(input.seq$seq.num,ws)),1,function(x){
      c(x,tail(input.seq$seq.num,-ws))
      }))
    for(i in 1:nrow(all.ord)){
        all.match <- match(all.ord[i,],input.seq$seq.num)

        ## rearrange linkage phases according to the current order
        for(j in 1:ws) {
            temp <- paste(as.character(link.phases[all.match[j],]*link.phases[all.match[j+1],]),collapse=".")
            phase[j] <- switch(EXPR=temp,
                               '1.1'   = 1,
                               '1.-1'  = 2,
                               '-1.1'  = 3,
                               '-1.-1' = 4
                               )
        }
        if(len > (ws+1)) phase[(ws+1):length(phase)] <- tail(input.seq$seq.phase,-ws)

        ## get initial values for recombination fractions
        for(j in 1:(len-1)){
            if(all.match[j] > all.match[j+1]) ind <- acum(all.match[j]-2)+all.match[j+1]
            else ind <- acum(all.match[j+1]-2)+all.match[j]
            if(length(which(list.init$phase.init[[ind]] == phase[j])) == 0) rf.init[j] <- 0.49 ## for safety reasons
            else rf.init[j] <- list.init$rf.init[[ind]][which(list.init$phase.init[[ind]] == phase[j])]
        }
        ## estimate parameters
        final.map <- est_map_hmm_out(geno=t(get(input.seq$data.name, pos=1)$geno[,all.ord[i,]]),
                                     type=get(input.seq$data.name, pos=1)$segr.type.num[all.ord[i,]],
                                     phase=phase,
                                     rf.vec=rf.init,
                                     verbose=FALSE,
                                     tol=tol)
        best.ord.phase[i,] <- phase
        best.ord.like[i] <- final.map$loglike
    }
    ## calculate LOD-Scores for alternative orders
    best.ord.LOD <- round((best.ord.like-max(best.ord.like))/log(10),2)
    ## which orders will be printed
    which.LOD <- which(best.ord.LOD > -LOD)

    if(length(which.LOD) > 1) {
        ## if any order to print, sort by LOD-Score
        order.print <- order(best.ord.LOD,decreasing=TRUE)
        all.ord <- all.ord[order.print,]
        best.ord.phase <- best.ord.phase[order.print,]
        best.ord.LOD <- best.ord.LOD[order.print]

        ## display results
	which.LOD <- which(best.ord.LOD > -LOD)
	LOD.print <- format(best.ord.LOD,digits=2,nsmall=2)
        cat("\n  Alternative orders:\n")
        for(j in which.LOD) {
            if(any(class(get(input.seq$data.name, pos=1))=="outcross"))
                cat("  ",all.ord[j,1:(ws+1)],ifelse(len > (ws+1),"... : ",": "),LOD.print[j],"( linkage phases:",best.ord.phase[j,1:ws],ifelse(len > (ws+1),"... )\n",")\n"))
            else
                cat("  ",all.ord[j,1:(ws+1)],ifelse(len > (ws+1),"... : ",": "),LOD.print[j],"\n")
        }
        cat("\n")
    }
  else cat(" OK\n\n")

#### middle positions
    if (len > (ws+1)) {
        for (p in 2:(len-ws)) {
            cat("...", input.seq$seq.num[p-1], "|", input.seq$seq.num[p:(p+ws-1)],"|", input.seq$seq.num[p+ws],"...", sep="-")

            ## create all possible alternative orders for the first subset
            all.ord <- t(apply(perm.tot(input.seq$seq.num[p:(p+ws-1)]),1,function(x) c(head(input.seq$seq.num,p-1),x,tail(input.seq$seq.num,-p-ws+1))))
            for(i in 1:nrow(all.ord)){
                all.match <- match(all.ord[i,],input.seq$seq.num)

                ## rearrange linkage phases according to the current order
                if(p > 2) phase[1:(p-2)] <- head(input.seq$seq.phase,p-2)
                for(j in (p-1):(p+ws-1)) {
                    temp <- paste(as.character(link.phases[all.match[j],]*link.phases[all.match[j+1],]),collapse=".")
                    phase[j] <- switch(EXPR=temp,
                                       '1.1'   = 1,
                                       '1.-1'  = 2,
                                       '-1.1'  = 3,
                                       '-1.-1' = 4
                                       )
                }
                if(p < (len-ws)) phase[(p+ws):length(phase)] <- tail(input.seq$seq.phase,len-p-ws)

                ## get initial values for recombination fractions
                for(j in 1:(len-1)){
                    if(all.match[j] > all.match[j+1]) ind <- acum(all.match[j]-2)+all.match[j+1]
                    else ind <- acum(all.match[j+1]-2)+all.match[j]
                    if(length(which(list.init$phase.init[[ind]] == phase[j])) == 0) rf.init[j] <- 0.49 ## for safety reasons
                    else rf.init[j] <- list.init$rf.init[[ind]][which(list.init$phase.init[[ind]] == phase[j])]
                }
                ## estimate parameters
                final.map <- est_map_hmm_out(geno=t(get(input.seq$data.name, pos=1)$geno[,all.ord[i,]]),
                                             type=get(input.seq$data.name, pos=1)$segr.type.num[all.ord[i,]],
                                             phase=phase,
                                             rf.vec=rf.init,
                                             verbose=FALSE,
                                             tol=tol)
                best.ord.phase[i,] <- phase
                best.ord.like[i] <- final.map$loglike
            }
            ## calculate LOD-Scores for alternative orders
            best.ord.LOD <- round((best.ord.like-max(best.ord.like))/log(10),2)
            ## which orders will be printed
            which.LOD <- which(best.ord.LOD > -LOD)

            if(length(which.LOD) > 1) {
                ## if any order to print, sort by LOD-Score
                order.print <- order(best.ord.LOD,decreasing=TRUE)
                all.ord <- all.ord[order.print,]
                best.ord.phase <- best.ord.phase[order.print,]
                best.ord.LOD <- best.ord.LOD[order.print]

                ## display results
                which.LOD <- which(best.ord.LOD > -LOD)
                LOD.print <- format(best.ord.LOD,digits=2,nsmall=2)
                cat("\n  Alternative orders:\n")
                for(j in which.LOD) {
                    if(any(class(get(input.seq$data.name, pos=1))=="outcross"))
                        cat(ifelse(p>2,"  ...","  "),all.ord[j,(p-1):(p+ws)],ifelse((p+ws)<len,"... : ",": "),LOD.print[j],"( linkage phases:",ifelse(p>2,"...","\b"),best.ord.phase[j,(p-1):(p+ws-1)],ifelse((p+ws)<len,"... )\n",")\n"))
                    else
                        cat(ifelse(p>2,"  ...","  "),all.ord[j,(p-1):(p+ws)],ifelse((p+ws)<len,"... : ",": "),LOD.print[j],"\n")
                }
                cat("\n")
            }
      else cat(" OK\n\n")
        }
    }

###### last position
    cat(input.seq$seq.num[len-ws], "|" , tail(input.seq$seq.num,ws), sep="-")
    ## create all possible alternative orders for the first subset
    all.ord <- t(apply(perm.tot(tail(input.seq$seq.num,ws)),1,function(x) c(head(input.seq$seq.num,-ws),x)))
    for(i in 1:nrow(all.ord)){
        all.match <- match(all.ord[i,],input.seq$seq.num)

        ## rearrange linkage phases according to the current order
        if(len > (ws+1)) phase[1:(len-ws-1)] <- head(input.seq$seq.phase,-ws)
        for(j in (len-ws):(len-1)) {
            temp <- paste(as.character(link.phases[all.match[j],]*link.phases[all.match[j+1],]),collapse=".")
            phase[j] <- switch(EXPR=temp,
                               '1.1'   = 1,
                               '1.-1'  = 2,
                               '-1.1'  = 3,
                               '-1.-1' = 4
                               )
        }

        ## get initial values for recombination fractions
        for(j in 1:(len-1)){
            if(all.match[j] > all.match[j+1]) ind <- acum(all.match[j]-2)+all.match[j+1]
            else ind <- acum(all.match[j+1]-2)+all.match[j]
            if(length(which(list.init$phase.init[[ind]] == phase[j])) == 0) rf.init[j] <- 0.49 ## for safety reasons
            else rf.init[j] <- list.init$rf.init[[ind]][which(list.init$phase.init[[ind]] == phase[j])]
        }
        ## estimate parameters
        final.map <- est_map_hmm_out(geno=t(get(input.seq$data.name, pos=1)$geno[,all.ord[i,]]),
                                     type=get(input.seq$data.name, pos=1)$segr.type.num[all.ord[i,]],
                                     phase=phase,
                                     rf.vec=rf.init,
                                     verbose=FALSE,
                                     tol=tol)
        best.ord.phase[i,] <- phase
        best.ord.like[i] <- final.map$loglike
    }
    ## calculate LOD-Scores for alternative orders
    best.ord.LOD <- round((best.ord.like-max(best.ord.like))/log(10),2)
    ## which orders will be printed
    which.LOD <- which(best.ord.LOD > -LOD)

    if(length(which.LOD) > 1) {
        ## if any order to print, sort by LOD-Score
        order.print <- order(best.ord.LOD,decreasing=TRUE)
        all.ord <- all.ord[order.print,]
        best.ord.phase <- best.ord.phase[order.print,]
        best.ord.LOD <- best.ord.LOD[order.print]

        ## display results
	which.LOD <- which(best.ord.LOD > -LOD)
	LOD.print <- format(best.ord.LOD,digits=2,nsmall=2)
        cat("\n  Alternative orders:\n")

        for(j in which.LOD) {
            if(any(class(get(input.seq$data.name, pos=1))=="outcross"))
                cat(ifelse(len > (ws+1),"  ...","  "),all.ord[j,(len-ws):len],": ",LOD.print[j],"( linkage phases:",ifelse(len > (ws+1),"...","\b"),best.ord.phase[j,(len-ws):(len-1)],")\n")
            else
                cat(ifelse(len > (ws+1),"  ...","  "),all.ord[j,(len-ws):len],": ",LOD.print[j],"\n")

        }
        cat("\n")
    }
  else cat(" OK\n\n")
}

                                        # end of file
