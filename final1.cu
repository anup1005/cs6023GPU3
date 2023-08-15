/*
 * Title: CS6023, GPU Programming, Jan-May 2023, Assignment-3
 * Description: Activation Game 
 */

#include <cstdio>        // Added for printf() function 
#include <sys/time.h>    // Added to get time of day
#include <cuda.h>
#include <bits/stdc++.h>
#include <fstream>
#include "graph.hpp"
 
using namespace std;

__device__ int temp;
// __device__ int count;
ofstream outfile; // The handle for printing the output
/******************************Write your kerenels here ************************************/
__global__ void settemp(int lastind){
    temp=lastind;
}

// __global__ void setcount(int lastind){
//     count=0;
// }


__global__ void mykernel(int *d_apr,int total){
    int tid= blockIdx.x*blockDim.x+threadIdx.x;
    if(tid<total){
        if(d_apr[tid]==0){
            atomicMax(&temp,tid);
        }
    }
}




//favkernel<<<numblocks,1024>>>(d_offset,d_csrList,startedge_ind,totaledges,temp,d_aid,mynode)
__global__ void favkernel(int* d_offset,int* d_csrList,int startind,int total,int *d_aid,int value){
    int tid=blockIdx.x*blockDim.x+threadIdx.x;
    if(tid<total){
        int csrind=startind+tid;
        if(value==1){
            atomicMax(&temp,d_csrList[csrind]);
            atomicAdd(&d_aid[d_csrList[csrind]],value);
        //atomicInc((unsigned int *)(d_aid[d_csrList[csrind]]),INT_MAX);}
        }
        else if(value==-1){
            atomicAdd(&d_aid[d_csrList[csrind]],value);
        }
}
}
    
/**************************************END*************************************************/



//Function to write result in output file
void printResult(int *arr, int V,  char* filename){
    outfile.open(filename);
    for(long int i = 0; i < V; i++){
        outfile<<arr[i]<<" ";   
    }
    outfile.close();
}

/**
 * Timing functions taken from the matrix multiplication source code
 * rtclock - Returns the time of the day 
 * printtime - Prints the time taken for computation 
 **/
double rtclock(){
    struct timezone Tzp;
    struct timeval Tp;
    int stat;
    stat = gettimeofday(&Tp, &Tzp);
    if (stat != 0) printf("Error return from gettimeofday: %d", stat);
    return(Tp.tv_sec + Tp.tv_usec * 1.0e-6);
}

void printtime(const char *str, double starttime, double endtime){
    printf("%s%3f seconds\n", str, endtime - starttime);
}

int main(int argc,char **argv){
    // Variable declarations
    int V ; // Number of vertices in the graph
    int E; // Number of edges in the graph
    int L; // number of levels in the graph

    //Reading input graph
    char *inputFilePath = argv[1];
    graph g(inputFilePath);

    //Parsing the graph to create csr list
    g.parseGraph();

    //Reading graph info 
    V = g.num_nodes();
    E = g.num_edges();
    L = g.get_level();


    //Variable for CSR format on host
    int *h_offset; // for csr offset
    int *h_csrList; // for csr
    int *h_apr; // active point requirement

    //reading csr
    h_offset = g.get_offset();
    h_csrList = g.get_csr();   
    h_apr = g.get_aprArray();
    
    // Variables for CSR on device
    int *d_offset;
    int *d_csrList;
    int *d_apr; //activation point requirement array
    int *d_aid; // acive in-degree array
    //Allocating memory on device 
    cudaMalloc(&d_offset, (V+1)*sizeof(int));
    cudaMalloc(&d_csrList, E*sizeof(int)); 
    cudaMalloc(&d_apr, V*sizeof(int)); 
    cudaMalloc(&d_aid, V*sizeof(int));




    //copy the csr offset, csrlist and apr array to device
    cudaMemcpy(d_offset, h_offset, (V+1)*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_csrList, h_csrList, E*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_apr, h_apr, V*sizeof(int), cudaMemcpyHostToDevice);

    // variable for result, storing number of active vertices at each level, on host
    int *h_activeVertex,*h_aid;
    h_activeVertex = (int*)malloc(L*sizeof(int));
    h_aid = (int*)malloc(V*sizeof(int));
    // setting initially all to zero
    memset(h_activeVertex, 0, L*sizeof(int));
    memset(h_aid, 0, V*sizeof(int));

    // variable for result, storing number of active vertices at each level, on device
    int *d_activeVertex;
	cudaMalloc(&d_activeVertex, L*sizeof(int));
    cudaMemset(d_activeVertex,0,L*sizeof(int));
    cudaMemset(d_aid,0,V*sizeof(int));


/***Important***/


// Make sure to use comments

/***END***/
double starttime = rtclock(); 

/*********************************CODE AREA*****************************************/
// int *temp;
// cudaMalloc(&temp,1*sizeof(int));
// cudaMemset(&temp,69,1*sizeof(int));



// int a=69;
// settemp<<<1,1>>>(a);
// cudaDeviceSynchronize();
// int target;
// cudaMemcpyFromSymbol(&target,temp, sizeof(int));
// printf("\ntemp in main is target and its value is %d\n",target);

int destination=-11;



int startind=0;
int lastind;
int total=min(10000,V);
int numblocks=  ceil(float(total)/ 1024);
int a=0;
settemp<<<1,1>>>(a);
cudaDeviceSynchronize();
mykernel<<<numblocks,1024>>>(d_apr,total);

cudaMemcpyFromSymbol(&lastind,temp, sizeof(int));


printf("last node in the first layer is %d",lastind);



int* Vlayers=(int *)malloc(L*sizeof(int));
memset(Vlayers, 0, L*sizeof(int));
Vlayers[0]=lastind+1;
printf("no. of layers are %d\n",L);

// printf("\n\n\nprinting Vlayers before editing\n");
// for(int i=0;i<L;i++){
//     printf("%d   ",Vlayers[i]);
// }
printf("taarak mehta\n");


cudaDeviceSynchronize();
int ch=0;

printf("INITIALLY startind is %d lastind is %d\n",startind,lastind);

while(lastind!=V-1){
    settemp<<<1,1>>>(lastind);
    for(int mynode=startind;mynode<=lastind;mynode++){

        int startedge_ind=h_offset[mynode];
        int endedge_ind=h_offset[mynode+1]-1;
        int totaledges= endedge_ind-startedge_ind+1;
        int numblocks=ceil(float(totaledges)/1024);
        favkernel<<<numblocks,1024>>>(d_offset,d_csrList,startedge_ind,totaledges,d_aid,1);

    }
    cudaDeviceSynchronize();
    int target;
    cudaMemcpyFromSymbol(&target,temp, sizeof(int));
    startind=lastind+1;
    lastind=target;
    ch+=1;
    Vlayers[ch]=lastind+1;
}




printf("\n\n\n");
printf("hello MR. Anup");
/*
    mere Vlayers s 5,10,14,17,20 aa gaye h
*/

/*
    mere d_aid m sare edges k degree aa gaye h
*/

cudaMemcpy(h_aid, d_aid, V*sizeof(int), cudaMemcpyDeviceToHost);

// printf("\n\n\nprinting Vlayers after editing\n");
// for(int i=0;i<L;i++){
//     printf("%d   ",Vlayers[i]);
// }



// printf("\nprinting just indegree after accounting each and every edge\n");
// for(int i=0;i<V;i++){
//     printf("%d  ",h_aid[i]);
// }
printf("\n anup just final step remaining\n");



h_activeVertex[0]=Vlayers[0];

for(int i=1;i<L;i++){
    printf("layer no. %d",i);
    int startnode=Vlayers[i-1];
    int lastnode=Vlayers[i]-1;
    //printf("layer%d    startnode%d   lastnode%d   ",i,startnode,lastnode);
    int count=0;
    int lastinactive=INT_MIN;
    for(int mynode=startnode;mynode<=lastnode;mynode++){
        if(h_aid[mynode]>=h_apr[mynode]){
            //printf("node active %d\n",mynode);
            count++;
           // printf("+1 count =  %d",count );
        }
       else{
        if(lastinactive+2==mynode){

            int startedge_ind=h_offset[mynode-1];
            int endedge_ind=h_offset[mynode]-1;
            int totaledges= endedge_ind-startedge_ind+1;
            int numblocks=ceil(float(totaledges)/1024);
            count--;
            favkernel<<<numblocks,1024>>>(d_offset,d_csrList,startedge_ind,totaledges,d_aid,-1);
            cudaMemcpy(h_aid, d_aid, V*sizeof(int), cudaMemcpyDeviceToHost);
        }
        lastinactive=mynode;
        int startedge_ind=h_offset[mynode];
        int endedge_ind=h_offset[mynode+1]-1;
        int totaledges= endedge_ind-startedge_ind+1;
        int numblocks=ceil(float(totaledges)/1024);
        favkernel<<<numblocks,1024>>>(d_offset,d_csrList,startedge_ind,totaledges,d_aid,-1);
        cudaMemcpy(h_aid, d_aid, V*sizeof(int), cudaMemcpyDeviceToHost);
    }
}
    printf("   %d  \n",count);
    cudaDeviceSynchronize();
    h_activeVertex[i]=count;
}
printf("\n my answeris\n");
for(int i=0;i<L;i++){
    printf("%d   ",h_activeVertex[i]);
}
printf("\nhello world\n");




    
 

    
   
    
    

     

/********************************END OF CODE AREA**********************************/
double endtime = rtclock();  
printtime("GPU Kernel time: ", starttime, endtime);  

// --> Copy C from Device to Host
char outFIle[30] = "./output.txt" ;
printResult(h_activeVertex, L, outFIle);
if(argc>2)
{
    for(int i=0; i<L; i++)
    {
        printf("level = %d , active nodes = %d\n",i,h_activeVertex[i]);
    }
}

    return 0;
}
