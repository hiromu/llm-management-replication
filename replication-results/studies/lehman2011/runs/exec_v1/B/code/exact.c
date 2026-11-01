#include <R.h>
#include <Rinternals.h>
#include <math.h>
#include <stdlib.h>
/* Exact conditional Bernoulli likelihood. Exponential tilting changes neither
   the conditional distribution nor its derivatives. Forward probabilities and
   a reverse pass give each inclusion probability in O(n min(m,n-m)). */
static double sigmoid(double x) { return x>=0 ? 1/(1+exp(-x)) : exp(x)/(1+exp(x)); }
static double softplus(double x) { return fmax(x,0)+log1p(exp(-fabs(x))); }
SEXP conditional_kernel(SEXP etaS, SEXP yS, SEXP lengthsS) {
  int N=LENGTH(etaS), G=LENGTH(lengthsS), off=0;
  SEXP out=PROTECT(allocVector(VECSXP,2));
  SEXP llS=PROTECT(allocVector(REALSXP,1));
  SEXP rS=PROTECT(allocVector(REALSXP,N));
  double ll=0, *eta=REAL(etaS), *y=REAL(yS), *res=REAL(rS);
  for(int g=0;g<G;g++) {
    R_CheckUserInterrupt();
    int n=INTEGER(lengthsS)[g], m=0;
    for(int i=0;i<n;i++) m+=(int)y[off+i];
    if(m==0 || m==n) { for(int i=0;i<n;i++) res[off+i]=0; off+=n; continue; }
    int flip=m>n/2; if(flip) m=n-m;
    int w=m+1; size_t size=((size_t)n+1)*w;
    double *F=calloc(size,sizeof(double)), *B=calloc(w,sizeof(double)), *p=calloc(n,sizeof(double));
    if(!F || !B || !p) {free(F);free(B);free(p);error("Exact recursion allocation failed");}
    double lo=-40,hi=40;
    for(int i=0;i<n;i++) {double e=flip?-eta[off+i]:eta[off+i];lo=fmin(lo,-e-40);hi=fmax(hi,-e+40);}
    double a=0;
    for(int it=0;it<70;it++) {a=(lo+hi)/2;double s=0;for(int i=0;i<n;i++) s+=sigmoid((flip?-eta[off+i]:eta[off+i])+a);if(s>m)hi=a;else lo=a;}
    F[0]=1; double base=0;
    for(int i=0;i<n;i++) {
      double e=(flip?-eta[off+i]:eta[off+i])+a, yy=flip?1-y[off+i]:y[off+i];
      p[i]=sigmoid(e); base+=yy*e-softplus(e);
      double *old=F+(size_t)i*w,*next=old+w;
      int maxk=i+1<m?i+1:m;
      next[0]=old[0]*(1-p[i]);
      for(int k=1;k<=maxk;k++) next[k]=old[k]*(1-p[i])+old[k-1]*p[i];
    }
    double prob=F[(size_t)n*w+m];
    if(!(prob>0)) {free(F);free(B);free(p);error("Exact recursion probability underflow");}
    ll+=base-log(prob); B[m]=1;
    for(int i=n-1;i>=0;i--) {
      double inc=0,*old=F+(size_t)i*w;
      for(int k=0;k<m;k++) inc+=old[k]*B[k+1];
      double q=p[i]*inc/prob; if(flip) q=1-q;
      res[off+i]=y[off+i]-q;
      for(int k=0;k<m;k++) B[k]=(1-p[i])*B[k]+p[i]*B[k+1];
      B[m]*=(1-p[i]);
    }
    free(F);free(B);free(p); off+=n;
  }
  REAL(llS)[0]=ll;SET_VECTOR_ELT(out,0,llS);SET_VECTOR_ELT(out,1,rS);UNPROTECT(3);return out;
}
