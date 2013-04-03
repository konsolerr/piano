diffExp <- function(arrayData, contrasts, chromosomeMapping,
                                   fitMethod="ls", adjustMethod="fdr", significance=0.001, 
                                   plot=TRUE, heatmapCutoff=1e-10,
                                   colors=c("red","green","blue","yellow","orange",
                                   "purple","tan","cyan","gray60","black"),
                                   save=FALSE, verbose=TRUE) {

  #require(marray)
  #require(gplots)
  if(!try(require(limma))) stop("package limma is missing")
  
  # Argument check:
  if(!fitMethod %in% c("ls","robust")) {
    stop("incorrect value of argument fitMethod")
  }
  if(!adjustMethod %in% c("holm","hochberg","hommel","bonferroni","BH","BY","fdr","none")) {
    stop("incorrect value of argument adjustMethod")
  }
  if(class(plot) == "logical") {
     if(plot) {
        venn <- heatmap <- polarPlot <- TRUE  
     } else {
        venn <- heatmap <- polarPlot <- FALSE
     }
  } else if(class(plot) == "character") {
     venn <- heatmap <- polarPlot <- FALSE
     if("venn" %in% plot) venn <- TRUE
     if("heatmap" %in% plot) heatmap <- TRUE
     if("polarplot" %in% plot) polarPlot <- TRUE
  } else {
     stop("argument plot has to be either TRUE, FALSE or a character string")
  }
  
  savedirFig <- paste(getwd(),"/Piano_Results/Figures/DifferentialExpression", sep="")
  savedirPval <- paste(getwd(),"/Piano_Results/pValues/genes",sep="")
  
  # Verbose function:
  .verb <- function(message, verbose) {
    if(verbose == TRUE) {
      message(message)
    }
  }
  
  saveFig <- save
  savePval <- save
  
  
  # Get factors from setup and sort according to dataNorm columns
  factors <- extractFactors(arrayData)


  # Run lmFit
  .verb("Fitting linear models...", verbose)
  factors <- factor(factors$factors[,1])
  designMatrix <- model.matrix(~0+factors)
  colnames(designMatrix) <- levels(factors)
  dataForLimma <- arrayData$dataNorm
  fitLm <- lmFit(dataForLimma, design=designMatrix, method=fitMethod, maxit=200)


  # Run ebayes
  contrastMatrix <- makeContrasts(contrasts=contrasts, levels=levels(factors))
  fitContrasts <- contrasts.fit(fitLm,contrasts=contrastMatrix)
  fitContrasts <- eBayes(fitContrasts)
  .verb("...done", verbose)
  
  
  # Venn diagram
  if(venn == TRUE) {
    if(length(contrasts) <= 5) {
      .verb("Generating Venn diagrams...", verbose)
      vennInfo <- decideTests(fitContrasts,adjust.method=adjustMethod,p.value=significance)
      # Plot
      if(saveFig == FALSE) {
        if(length(contrasts) <= 3) {
          dev.new()
          vennDiagram(vennInfo, cex=1, main=paste("Venn diagram (p-value adjustment: ",adjustMethod,", p<",significance,")",sep=""),
                      circle.col=colors, names="")
          dev.new()
          plot.new()
          title(main="Legend Venn diagram")
          legend(x=0.05, y=0.8, legend=colnames(fitContrasts),fill=colors)

        } else {
          dev.new()
          vennInfoTmp <- as.data.frame(vennInfo,stringsAsFactors=FALSE)
          vennInfoTmp[vennInfoTmp == -1] <- 1
          colnames(vennInfoTmp) <- LETTERS[1:ncol(vennInfoTmp)]
          venn(vennInfoTmp)
          
          dev.new()
          plot.new()
          title(main="Legend Venn diagram")
          for(i in 1:length(contrasts)) {
            text(x=0.2, y=(1-0.05*i), paste(LETTERS[i],": ",contrasts[i],sep=""), adj=c(0,0))
          }
        }
      }
      .verb("...done", verbose)
      #Save
      if(saveFig == TRUE) {
        dirStat <- dir.create(savedirFig, recursive=TRUE, showWarnings=FALSE)
        if(dirStat == TRUE) {
          .verb(paste("Creating new directory:",savedirFig), verbose)
        }
        # Venn diagram
        vennFileName = paste("venn_pval_adj_",adjustMethod,".pdf",sep="")
        vennFilePath = paste(savedirFig,"/",vennFileName,sep="")
        .verb("Saving Venn diagram...", verbose)
        if(file.exists(vennFilePath)) {
          .verb(paste("Warning: ",vennFileName," already exists in directory: overwriting old file...",sep=""), verbose)
        }
        if(length(contrasts) <= 3) {
          pdf(file=vennFilePath,paper="a4")
          vennDiagram(vennInfo, cex=1, main=paste("Venn diagram (p-value adjustment: ",adjustMethod,", p<",significance,")",sep=""),
                      circle.col=c("red","green","blue"), names="")
        } else {
          vennInfoTmp <- as.data.frame(vennInfo,stringsAsFactors=FALSE)
          vennInfoTmp[vennInfoTmp == -1] <- 1
          colnames(vennInfoTmp) <- LETTERS[1:ncol(vennInfoTmp)]
          pdf(file=vennFilePath, paper="a4", onefile=FALSE)
          venn(vennInfoTmp)
        }
        tmp <- dev.off()
        .verb("...done", verbose)
        
        # Venn legend
        vennFileName = "vennLegend.pdf"
        vennFilePath = paste(savedirFig,"/",vennFileName,sep="")
        .verb("Saving Venn legend...", verbose)
        if(file.exists(vennFilePath)) {
          .verb("Warning: vennLegend.pdf already exists in directory: overwriting old file...", verbose)
        }
        pdf(file=vennFilePath, paper="a4")
        plot.new()
        if(length(contrasts) <= 3) {
          title(main="Legend Venn diagram")
          legend(x=0.05, y=0.8, legend=colnames(fitContrasts),fill=c("red","green","blue"))
        } else {
          title(main="Legend Venn diagram")
          for(i in 1:length(contrasts)) {
            text(x=0.2, y=(1-0.05*i), paste(LETTERS[i],": ",contrasts[i],sep=""), adj=c(0,0))
          }
        }
        tmp <- dev.off()
        .verb("...done", verbose)
      }
    } else {
      warning("can not create a Venn diagram for more than 5 samples")
    }
  }
  
  # Calculate p-values for each contrast:
  if(savePval == TRUE) {
    # Save pval-files, one for each contrast
    dirStat <- dir.create(savedirPval, recursive=TRUE, showWarnings=FALSE)
    if(dirStat == TRUE) {
      .verb(paste("Creating new directory:",savedirPval), verbose)
    }
  }
  pValues <- NA
  foldChanges <- NA
  topTabList <- list()
  for(i in 1:length(contrasts)) {
    if(savePval == TRUE) {
      .verb(paste("Saving p-values for contrast ",colnames(fitContrasts)[i],"...",sep=""), verbose)
      pvalFileName <- paste(colnames(fitContrasts)[i],"_pval_adj_",adjustMethod,".txt",sep="")
      pvalFilePath <- paste(savedirPval,"/",pvalFileName,sep="")
      if(file.exists(pvalFilePath)) {
        .verb(paste("Warning: ",pvalFileName," already exists in directory: overwriting old file...",sep=""), verbose)
      }
    } else {
      .verb(paste("Calculating p-values for contrast ",colnames(fitContrasts)[i],"...",sep=""), verbose)
    }
    topTab <- topTable(fitContrasts,coef=i,adjust.method=adjustMethod,sort.by="none",number=nrow(dataForLimma))
    
    # If gene names exist, add them:
    tmp <- arrayData$annotation$geneName
    if(!is.null(tmp)) {
       names(tmp) <- rownames(arrayData$annotation)
       topTab <- merge(y=topTab,x=tmp,by.y="ID",by.x="row.names",all.y=TRUE)
       colnames(topTab)[1:2] <- c("ProbesetID","GeneName") 
    } else {
       colnames(topTab)[1] <- c("ProbesetID") 
    }
    
    topTabList[[i]] <- topTab
    pValues <- cbind(pValues,topTab$adj.P.Val)  # P-values for all contrasts, to be further used below
    foldChanges <- cbind(foldChanges,topTab$logFC)  # FC for all contrasts
    if(savePval == TRUE) {
      write.table(topTab,sep="\t",file=pvalFilePath,
                  row.names=FALSE, quote=FALSE)
    }
    .verb("...done", verbose)
  }
  pValues <- as.data.frame(pValues[,2:ncol(pValues)],stringsAsFactors=FALSE)
  rownames(pValues) <- rownames(fitContrasts)
  colnames(pValues) <- colnames(fitContrasts)
  foldChanges <- as.data.frame(foldChanges[,2:ncol(foldChanges)],stringsAsFactors=FALSE)
  rownames(foldChanges) <- rownames(fitContrasts)
  colnames(foldChanges) <- colnames(fitContrasts)
  
  
  # Heatmap
  if(heatmap == TRUE) {
    .verb("Generating heatmap...", verbose)
    genesInHeatmap <- vector()
    for(i in 1:ncol(pValues)) {
      genesInHeatmap <- c(genesInHeatmap, rownames(pValues)[pValues[,i] < heatmapCutoff])
    }
    if(length(unique(genesInHeatmap)) < 2) {
      warning("No genes were selected, change the heatmapCutoff. Omitting heatmap.")
    } else {
      genesInHeatmap <- unique(genesInHeatmap)
      heatmapMatrix <- as.matrix(arrayData$dataNorm[rownames(arrayData$dataNorm) %in% genesInHeatmap,])
      if("annotation" %in% attributes(arrayData)$names) {
         geneNamesHeatmap <- arrayData$annotation[rownames(arrayData$annotation) %in% genesInHeatmap,]
         for(j in 1:nrow(heatmapMatrix)) {
            tmp <- geneNamesHeatmap[rownames(geneNamesHeatmap) == rownames(heatmapMatrix)[j],1]
            if(length(tmp) == 1) {
               rownames(heatmapMatrix)[j] <- tmp
            }
         }
      }
      if(saveFig == TRUE) {
        dirStat <- dir.create(savedirFig, recursive=TRUE, showWarnings=FALSE)
        if(dirStat == TRUE) {
          .verb(paste("Creating new directory:",savedirFig), verbose)
        }
        figFileName = paste("heatmap_genes.pdf",sep="")
        figFilePath = paste(savedirFig,"/",figFileName,sep="")
        .verb("Saving heatmap...", verbose)
        if(file.exists(figFilePath)) {
          .verb(paste("Warning: ",figFileName," already exists in directory: overwriting old file...",sep=""), verbose)
        }
        pdf(file=figFilePath,paper="a4", width=21, height=29)
      } else {
        dev.new()
      }
      heatmap.2(heatmapMatrix, trace="none", scale="none", margins=c(10,5),
                lwid=c(2,10), lhei=c(2,20), key=FALSE)
      if(saveFig == TRUE) {
        tmp <- dev.off()
        figFileName = paste("heatmap_genes_colorkey.pdf",sep="")
        figFilePath = paste(savedirFig,"/",figFileName,sep="")
        if(file.exists(figFilePath)) {
          .verb(paste("Warning: ",figFileName," already exists in directory: overwriting old file...",sep=""), verbose)
        }
        pdf(file=figFilePath,paper="a4", width=4, height=3)
      } else {
        dev.new()
      }
      maColorBar(seq(from=min(heatmapMatrix),to=max(heatmapMatrix),length.out=100),
                 k=5,main="Color key")
      title(xlab="expression values")
      if(saveFig == TRUE) {
        tmp <- dev.off()
      }
      .verb("...done", verbose)
    }
  }  


  # Polar plot
  if(polarPlot == TRUE) {
    if("annotation" %in% attributes(arrayData)$names & missing(chromosomeMapping)) {
      polarPlot(pValues, chromosomeMapping=arrayData$annotation[,c(2,3)],
                colors=colors, save=saveFig, verbose=verbose)
    } else if(!missing(chromosomeMapping)) {
      polarPlot(pValues, chromosomeMapping=chromosomeMapping,
                colors=colors, save=saveFig, verbose=verbose)
    } else {
      warning("can not run PolarPlot: no chromosome mapping provided")
    }
  }
  
  names(topTabList) <- contrasts
  return(list(pValues=pValues,foldChanges=foldChanges,resTable=topTabList))
}