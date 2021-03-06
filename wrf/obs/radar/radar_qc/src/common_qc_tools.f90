MODULE COMMON_QC_TOOLS
!=======================================================================
!
! [PURPOSE:] Common quality control parameters computation
!
! [HISTORY:]
!   09/01/2014 Juan Ruiz created
!
!=======================================================================
!$USE OMP_LIB
  USE common
  USE common_radar_tools
  USE common_smooth2d
  IMPLICIT NONE
  PUBLIC

  !-------- RADAR SETTINGS 

  TYPE(RADAR) :: RADAR1


  !Default quality control configuration settings.

  !QC_CODES---------------------------------------------
  INTEGER,PARAMETER :: CODE_SPECKLE= 900
  INTEGER,PARAMETER :: CODE_BLOCKING = 901 
  INTEGER,PARAMETER :: CODE_BLOCKING_CORRECTED = 902
  INTEGER,PARAMETER :: CODE_CLUTTER  = 920
  INTEGER,PARAMETER :: CODE_CLUTTER_RECLASSIFIED= 921
  INTEGER,PARAMETER :: CODE_WEATHER_RECLASSIFIED= 1
  INTEGER,PARAMETER :: CODE_ECHO_TOP_FILTER=931
  INTEGER,PARAMETER :: CODE_ECHO_DEPTH_FILTER=932

  !--------GENERAL PARAMETERS ------------------------
  LOGICAL :: DEBUG_OUTPUT= .FALSE.   !Turns on individual parameter output.
  LOGICAL :: STATISTIC_OUTPUT=.TRUE. !Turns on output for statistical analysis of the parameters.
  LOGICAL :: COMPUTE_WEIGHT=.TRUE.   !Turns on weigth computation for QC.
  !Weight computation type. Naive Bayes and Fuzzy Logic uses the parameter pdf under clutter and 
  !weather conditions to compute the weigths. In Naive Bayes the final probability is obtained as a
  !product and in the Fuzzy Logic approach is obtained as weigthed sum.
  INTEGER :: WEIGHT_TYPE=1           !1-Naive Bayes Classification , 2-Fuzzy Logic Classification

  !--------PARAMETERS FOR STATISTIC OUTPUT------------
  INTEGER :: SKIP_AZ=5 , SKIP_R=10 , SKIP_ELEV=2 , ELEVMAX=20

  !--------FLAG IF TRUE, PREVIOUS TIME WEIGHTS WILL BE USED AS PRIOR DISTRIBUTION IN ECHO CLASSIFICATION.
  LOGICAL :: USE_PRIOR=.TRUE.        !Wether weigths computed in the previous time will be used as a prior
                                     !for the current time QC.

  !--------FLAG AND CONFIGURATION FOR SPATIAL ECHO RECLASIFICATION
  LOGICAL :: USE_SPATIAL_RECLASSIFICATION = .FALSE. !Reclasifies the data according to neighbors classification.
  REAL(r_size) :: RECLASSIFICATION_THRESHOLD=0.8d0
  INTEGER :: NXBOX_RC=2 , NYBOX_RC=2 , NZBOX_RC = 0
  REAL(r_size),PARAMETER :: WEATHER_PROBABILITY_THRESHOLD=0.5 !If clutter probability is over this value the point will be flagged as clutter.

  !--------FLAG AND CONFIGURATION FOR WIND FILTERING AND QC------
  LOGICAL :: FILTER_WIND = .FALSE.
  INTEGER :: FILTER_WIND_LAMBDA = 20
  REAL(r_size) :: MAX_WIND=50.0d0 , MIN_WIND=-50.0d0
  INTEGER :: NXBOX_WO=0 , NYBOX_WO=2 , NZBOX_WO=0
  REAL(r_size) ::  WIND_TVAR_THRESHOLD=4.0d0 !Temporal variances larger that this will be eliminated            
  REAL(r_size) ::  NUM_VR_THRESHOLD=3.0d0    !How many valid times do we need in the database.          

  !--------FLAG FOR SPATIAL FILTER FOR THE REFLECTIVITY
  LOGICAL :: FILTER_REFLECTIVITY = .FALSE.
  INTEGER :: FILTER_REFLECTIVITY_LAMBDA = 10
  REAL(r_size) :: MAX_REFLECTIVITY=90.0d0    !Upper limit for reflectivity values
  REAL(r_size) :: MIN_REFLECTIVITY=-20.0d0   !Lower limit for reflectivity values.

  !--------FLAG FOR THE COMPUTATION OF ATTENUATION ---------
  LOGICAL :: USE_ATTENUATION = .TRUE.   !Weather attenuation will be computed or not.
  REAL(r_size) :: B_COEF = (1/1.32)     !Use 1/1.32 for X band radar.
  REAL(r_size) :: A_COEF = (1/1.12e5)**(1/1.32) !Use (1/1.12e5)**(1/1.32) for X band radar.
  REAL(r_size) :: CALIBRATION_ERROR=1.0d0 !Use 1 if no information about the calibration error is available.
  
  !--------TERRAIN DATA FOR BEAM BLOCKING COMPUTATION ------
  CHARACTER(LEN=200)              ::  TERRAIN_FILE='./terrain.bin'
  REAL(r_size),ALLOCATABLE        ::  TOPOGRAPHY(:,:,:)
  LOGICAL                         ::  READ_TOPO=.TRUE.

  !---------ARRAYS WHERE QC DATA WILL BE STORED
  INTEGER     ,ALLOCATABLE        ::  QCFLAG(:,:,:)
  REAL(r_size),ALLOCATABLE        ::  ATTENUATION(:,:,:)
  REAL(r_size),ALLOCATABLE        ::  W_WEATHER(:,:,:)
  REAL(r_size),ALLOCATABLE        ::  WEATHER_PRIOR(:,:,:),WEIGHT_SUM(:,:,:)

  !-------- COLUMN METRICS PARAMETER  --------------------
  LOGICAL      :: USE_ECHO_TOP=.TRUE. 
  LOGICAL      :: USE_ECHO_BASE=.TRUE. 
  LOGICAL      :: USE_ECHO_DEPTH=.TRUE. 
  LOGICAL      :: USE_MAX_DBZ=.TRUE.
  LOGICAL      :: USE_MAX_DBZ_Z=.TRUE. 
  LOGICAL      :: USE_REF_VGRAD=.TRUE.
  INTEGER      :: MAX_ECHO_TOP_LEVS = 6
  REAL(r_size) :: MAX_Z_ECHO_TOP = 20.0d3
  REAL(r_size) :: MAX_R_ECHO_TOP = 60.0d3
  REAL(r_size) :: DX_ECHO_TOP    = 100.0d0
  REAL(r_size) :: DZ_ECHO_TOP    = 50.0d0
  REAL(r_size) :: DBZ_THRESHOLD_ECHO_TOP = 5.0d0 
  INTEGER      :: NXBOX_ECHO_TOP=5
  INTEGER      :: NYBOX_ECHO_TOP=1
  INTEGER      :: NZBOX_ECHO_TOP=0
  INTEGER, PARAMETER :: NPAR_ECHO_TOP_3D=6           !Controls the number of parameters otuput by the subroutine.
  INTEGER, PARAMETER :: NPAR_ECHO_TOP_2D=7

  REAL(r_size), PARAMETER :: ECHO_DEPTH_THRESHOLD=3000.0d0

  !-------- LOCAL MINIMUM OF LOCAL VARIANCE OF DBZ  --------------------
  LOGICAL      :: USE_LDBZVAR = .TRUE.
  INTEGER      :: NXBOX_LDBZVAR=1
  INTEGER      :: NYBOX_LDBZVAR=5
  INTEGER      :: NZBOX_LDBZVAR=1

  !-------- LOCAL "ISOLATION" OF THE REFLECTIVITY  --------------------
  LOGICAL      :: USE_SPECKLE = .TRUE.
  INTEGER      :: NXBOX_SPECKLE=2
  INTEGER      :: NYBOX_SPECKLE=2
  INTEGER      :: NZBOX_SPECKLE=0
  REAL(r_size) :: SPECKLE_THRESHOLD=0.30 !Points with percentaje of occupied gates lower than this value will be rejected.
  REAL(r_size) :: SPECKLE_REFLECTIVITY_THRESHOLD=0.0d0 !Reflectivity value to decide whether we have a cloud or not.

  !-------- BLOCKING OF THE REFLECTIVITY BY THE TERRAIN  --------------------
  LOGICAL      :: USE_BLOCKING = .TRUE.
  REAL(r_size) :: BLOCKING_THRESHOLD=0.5
  LOGICAL      :: CORRECT_REFLECTIVITY=.FALSE.

  !-------- TEXTURE OF REFLECITIVITY (TDBZ)  --------------------
  LOGICAL      :: USE_TDBZ = .TRUE.
  INTEGER      :: NXBOX_TDBZ=1
  INTEGER      :: NYBOX_TDBZ=5
  INTEGER      :: NZBOX_TDBZ=0

  !-------- SIGN OF REFLECITIVITY (SIGN)  --------------------
  LOGICAL      :: USE_SIGN = .TRUE.
  INTEGER      :: NXBOX_SIGN=1
  INTEGER      :: NYBOX_SIGN=5
  INTEGER      :: NZBOX_SIGN=0

  !-------- SPIN OF REFLECITIVITY (SPIN)  --------------------
  LOGICAL      :: USE_RSPIN = .TRUE.
  INTEGER      :: NXBOX_RSPIN=1
  INTEGER      :: NYBOX_RSPIN=5
  INTEGER      :: NZBOX_RSPIN=0
  REAL(r_size) :: SPIN_REFCHANGE_THRESHOLD=5.0d0 !Changes in reflectivity lower than this value
                                                 !will be ignored.

  !-------- TEMPORAL SIGN OF REFLECITIVITY (TSIGN)  --------------------
  LOGICAL      :: USE_TSIGN = .TRUE.
  INTEGER      :: NXBOX_TSIGN=1
  INTEGER      :: NYBOX_TSIGN=5
  INTEGER      :: NZBOX_TSIGN=0

  !-------- TEMPORAL WIND AVERAGE  --------------------
  LOGICAL      :: USE_TWA = .TRUE.
  INTEGER      :: NXBOX_TWA=0
  INTEGER      :: NYBOX_TWA=0
  INTEGER      :: NZBOX_TWA=0

  !-------- TEMPORAL WIND STD  --------------------
  LOGICAL      :: USE_TWS = .TRUE.
  INTEGER      :: NXBOX_TWS=0
  INTEGER      :: NYBOX_TWS=0
  INTEGER      :: NZBOX_TWS=0

  !-------- TEMPORAL WIND CORRELATION --------------------
  LOGICAL      :: USE_TWC = .TRUE.
  INTEGER      :: NXBOX_TWC=0
  INTEGER      :: NYBOX_TWC=0
  INTEGER      :: NZBOX_TWC=0

  !-------- TEMPORAL REFLECITIVITY CORRELATION --------------------
  LOGICAL      :: USE_TRC = .TRUE.
  INTEGER      :: NXBOX_TRC=0
  INTEGER      :: NYBOX_TRC=0
  INTEGER      :: NZBOX_TRC=0

  !-------- TEMPORAL REFLECITIVITY CORRELATION TEXTURE--------------------
  LOGICAL      :: USE_TRCT = .TRUE.
  INTEGER      :: NXBOX_TRCT=1
  INTEGER      :: NYBOX_TRCT=5
  INTEGER      :: NZBOX_TRCT=0

  !-------- TEMPORAL REF MAX TEMPORAL STD --------------------
  LOGICAL      :: USE_TRMS = .TRUE.
  INTEGER      :: NXBOX_TRMS=1
  INTEGER      :: NYBOX_TRMS=5
  INTEGER      :: NZBOX_TRMS=0

  !-------- TEMPORAL REF ANOMALY MSD --------------------
  LOGICAL      :: USE_TRAM = .TRUE.
  INTEGER      :: NXBOX_TRAM=1
  INTEGER      :: NYBOX_TRAM=5
  INTEGER      :: NZBOX_TRAM=0

  !-------- SPATIAL REF ANOMALY MSD --------------------
  LOGICAL      :: USE_SRAM = .TRUE.
  INTEGER      :: NXBOX_SRAM=1
  INTEGER      :: NYBOX_SRAM=5
  INTEGER      :: NZBOX_SRAM=0

  !-------- TEMPORAL WIND ANOMALY MSD --------------------
  LOGICAL      :: USE_TWAM = .TRUE.
  INTEGER      :: NXBOX_TWAM=1
  INTEGER      :: NYBOX_TWAM=5
  INTEGER      :: NZBOX_TWAM=0

  !-------- SPATIAL WIND ANOMALY MSD --------------------
  LOGICAL      :: USE_SWAM = .TRUE.
  INTEGER      :: NXBOX_SWAM=1
  INTEGER      :: NYBOX_SWAM=5
  INTEGER      :: NZBOX_SWAM=0

  !--------- OTHER FILTERS ------------------------------
  LOGICAL      :: USE_ECHO_TOP_FILTER=.TRUE.
  REAL(r_size) :: ECHO_TOP_FILTER_THRESHOLD=3000
  LOGICAL      :: USE_ECHO_DEPTH_FILTER=.TRUE.
  REAL(r_size) :: ECHO_DEPTH_FILTER_THRESHOLD=2000



  INTEGER(8)      :: TIMEOUT    !time yyyymmddhhMMSS for output



CONTAINS

SUBROUTINE RADAR_QC(reflectivity,wind,nt,qcedreflectivity,qcedwind)
!This routine performs the radar QC computing the requested fields.
IMPLICIT NONE
INTEGER     ,INTENT(IN)    ::  nt !Number of input times
REAL(r_size),INTENT(INOUT) :: reflectivity(radar1%na,radar1%nr,radar1%ne,nt) 
REAL(r_size),INTENT(INOUT) :: wind(radar1%na,radar1%nr,radar1%ne,nt)
REAL(r_size),INTENT(OUT)   :: qcedwind(radar1%na,radar1%nr,radar1%ne)
REAL(r_size),INTENT(OUT)   :: qcedreflectivity(radar1%na,radar1%nr,radar1%ne)
REAL(r_size),ALLOCATABLE   :: tmp_data_3d(:,:,:,:) , tmp_data_2d(:,:,:)
INTEGER                    :: ip , ia , ir , ie , center_index  , ii , jj , kk
REAL(r_sngl)               :: wout(4)
INTEGER                    :: mask(radar1%nr),lambda
REAL(r_size)               :: echo_top(radar1%na,radar1%nr,radar1%ne),echo_depth(radar1%na,radar1%nr,radar1%ne)
!=====================================================================
!
!This subroutine computes the parameters for QC and the weigths of the QC
!There are qcedwind and qcedreflectivity in which the result of the QC
!is stored. The original wind and reflectivity with the time dependency
!of this fiels is modified only when needed but most of the clutter 
!echoes are retained in these variables.
!
!=====================================================================

   IF(.NOT.ALLOCATED(ATTENUATION))ALLOCATE(ATTENUATION(radar1%na,radar1%nr,radar1%ne))

   ATTENUATION=1.0d0 !Initialize attenuation.

   IF(.NOT.ALLOCATED(QCFLAG))ALLOCATE(QCFLAG(radar1%na,radar1%nr,radar1%ne))

   QCFLAG=0 !Initialize QC flag

!=====================================================================
! WEIGHT INITIALIZATION
!=====================================================================

   IF(.NOT.ALLOCATED(W_WEATHER) .AND. COMPUTE_WEIGHT )THEN
     ALLOCATE(W_WEATHER(radar1%na,radar1%nr,radar1%ne))
     ALLOCATE(WEATHER_PRIOR(radar1%na,radar1%nr,radar1%ne))
     ALLOCATE(WEIGHT_SUM(radar1%na,radar1%nr,radar1%ne))
     W_WEATHER=0.5d0   !Equal probability initialization.
     WEATHER_PRIOR=0.0d0 !Just to put something 
     WEIGHT_SUM=0.0d0    !Just to put something
   ENDIF
   IF(.NOT. USE_PRIOR .AND. COMPUTE_WEIGHT)THEN
     W_WEATHER=0.5d0  !Equal probability initialization.
     WRITE(6,*)"WEIGHTS ARE INITIALIZED WITH NO A PRIORI INFORMATION"
   ENDIF

   !Initialization of fuzzy logic related arrays.
   IF( COMPUTE_WEIGHT .AND. WEIGHT_TYPE == 2 .AND. USE_PRIOR)THEN
     WEATHER_PRIOR=W_WEATHER  !
     WEIGHT_SUM=0.0d0
   ENDIF 
   IF( COMPUTE_WEIGHT .AND. WEIGHT_TYPE == 2 .AND. .NOT. USE_PRIOR)THEN
     WEATHER_PRIOR=0.5d0
     WEIGHT_SUM=0.0d0
   ENDIF
  

!=====================================================================
! READ TOPOGRAPHY.
!=====================================================================

   IF( READ_TOPO )THEN  !Read topography in the first call to this routine.
    WRITE(6,*)'READING TOPOGRAPHY ',radar1%na,radar1%nr,radar1%ne
    ALLOCATE( topography(radar1%na , radar1%nr , radar1%ne ))
    CALL READ_TOPOGRAPHY
    READ_TOPO=.FALSE.
   ENDIF

! ---------------------------------------------------------------------------------
  !IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('refraw.grd',reflectivity(:,:,:,nt),reflectivity(:,:,:,nt))
  IF( USE_BLOCKING )THEN  !Compute terrain blocking.
    WRITE(6,*)'COMPUTING TERRAIN BLOCKING'
    CALL COMPUTE_BLOCKING(  reflectivity(:,:,:,nt),wind(:,:,:,nt) )
  ENDIF

!Output input wind and ref
   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('ref.grd',reflectivity(:,:,:,nt),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('ref.stat',reflectivity(:,:,:,nt),reflectivity(:,:,:,nt),timeout)
   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('wind.grd',wind(:,:,:,nt),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('wind.stat',wind(:,:,:,nt),reflectivity(:,:,:,nt),timeout)

!Initialize QC arrays

qcedwind=wind(:,:,:,nt)
qcedreflectivity=reflectivity(:,:,:,nt)

! Speckle filter

  IF( USE_SPECKLE )CALL SPECKLE_FILTER(qcedreflectivity(:,:,:))
  WHERE( qcedreflectivity == UNDEF )qcedwind=UNDEF !Apply the same speckle filter to the wind.

!================================================================================
!  REMOVE WIND OUTLIERS
!================================================================================

WRITE(6,*)"QC THE WIND"
ALLOCATE( tmp_data_3d(radar1%na,radar1%nr,radar1%ne,2) )

 CALL TIME_FUNCTIONS(wind,radar1%na,radar1%nr,radar1%ne,nt,'TVAR',tmp_data_3d(:,:,:,1))
 
 CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:,1),radar1%na,radar1%nr,radar1%ne,NXBOX_WO,NYBOX_WO,NZBOX_WO,'MAXN',tmp_data_3d(:,:,:,2),0.0d0)

 CALL TIME_FUNCTIONS(wind,radar1%na,radar1%nr,radar1%ne,nt,'COUN',tmp_data_3d(:,:,:,1))

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ia,ie,ir) 
 DO ia=1,radar1%na
   DO ir=1,radar1%nr
     DO ie=1,radar1%ne
       IF( tmp_data_3d(ia,ir,ie,2) > WIND_TVAR_THRESHOLD)THEN
         qcedwind(ia,ir,ie)=UNDEF
         wind(ia,ir,ie,nt)=UNDEF
       ENDIF
       IF( tmp_data_3d(ia,ir,ie,2) == UNDEF )THEN
         qcedwind(ia,ir,ie)=UNDEF
       ENDIF
       IF( tmp_data_3d(ia,ir,ie,1) < NUM_VR_THRESHOLD )THEN !
         qcedwind(ia,ir,ie)=UNDEF
       ENDIF
     ENDDO
   ENDDO
 ENDDO
!$OMP END PARALLEL DO

 IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('tws.grd',tmp_data_3d(:,:,:,2),reflectivity(:,:,:,nt))

 !tmp_data_3d(:,:,:,1)=ABS(wind(:,:,:,nt))
 !IF( USE_SPECKLE )CALL SPECKLE_FILTER(tmp_data_3d(:,:,:,1)) 
 !WHERE( tmp_data_3d(:,:,:,1) == UNDEF )
 !   qcedwind(:,:,:) = UNDEF
 !ENDWHERE

 !Eliminate wind outliers.
 WHERE( qcedwind(:,:,:) > MAX_WIND .OR. qcedwind(:,:,:) < MIN_WIND)
    qcedwind(:,:,:) = UNDEF
 ENDWHERE



IF(FILTER_WIND)THEN
!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ia,ie,mask)
 DO ia=1,radar1%na
  DO ie=1,radar1%ne 
   mask=1
   WHERE( qcedwind(ia,:,ie) == UNDEF )mask=0
   CALL filter_2d(qcedwind(ia,:,ie),tmp_data_3d(ia,:,ie,1),mask,FILTER_WIND_LAMBDA,radar1%nr,1)
   qcedwind(ia,:,ie)=tmp_data_3d(ia,:,ie,1)
  ENDDO
 
 !Eliminate wind outliers.
 WHERE( qcedwind(ia,:,:) > MAX_WIND .OR. qcedwind(ia,:,:) < MIN_WIND)
    qcedwind(ia,:,:) = UNDEF
 ENDWHERE


 ENDDO
!$OMP END PARALLEL DO
ENDIF

DEALLOCATE( tmp_data_3d )


!================================================================================
! Begining of parameter computation section
!================================================================================


! --------------------------------------------------------------------------------
IF( USE_ECHO_TOP .OR. USE_ECHO_BASE .OR. USE_ECHO_DEPTH .OR. USE_MAX_DBZ .OR. USE_MAX_DBZ_Z .OR. USE_REF_VGRAD )THEN
  WRITE(6,*)'COMPUTING 3D-ECHO-TOP'
ALLOCATE( tmp_data_3d(radar1%na,radar1%nr,radar1%ne,NPAR_ECHO_TOP_3D) )
ALLOCATE( tmp_data_2d(radar1%na,radar1%nr,NPAR_ECHO_TOP_2D) )
CALL COMPUTE_ECHO_TOP(reflectivity(:,:,:,nt),radar1%z(1,:,:),radar1%distance_to_radar,radar1%na,radar1%nr,radar1%ne,tmp_data_3d,tmp_data_2d)

   tmp_data_3d(:,:,:,1)=tmp_data_3d(:,:,:,1)-topography !Compute echo_top over the terrain.
   tmp_data_3d(:,:,:,2)=tmp_data_3d(:,:,:,2)-topography !Compute echo_base over the terrain.
   echo_top=tmp_data_3d(:,:,:,1)
   echo_depth=tmp_data_3d(:,:,:,3)


   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('echo_top.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('echo_base.grd',tmp_data_3d(:,:,:,2),reflectivity(:,:,:,nt))
   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('echo_depth.grd',tmp_data_3d(:,:,:,3),reflectivity(:,:,:,nt))
   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('max_ref_z.grd',tmp_data_3d(:,:,:,5),reflectivity(:,:,:,nt))
   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('ref_vgrad.grd',tmp_data_3d(:,:,:,6),reflectivity(:,:,:,nt))

   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('echo_top.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('echo_base.stat',tmp_data_3d(:,:,:,2),reflectivity(:,:,:,nt),timeout)
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('echo_depth.stat',tmp_data_3d(:,:,:,3),reflectivity(:,:,:,nt),timeout)
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('max_ref_z.stat',tmp_data_3d(:,:,:,5),reflectivity(:,:,:,nt),timeout)
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('ref_vgrad.stat',tmp_data_3d(:,:,:,6),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT .AND. USE_ECHO_TOP)CALL GET_WEIGHT('echo_top',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)
   IF( COMPUTE_WEIGHT .AND. USE_ECHO_BASE)CALL GET_WEIGHT('echo_base',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,2),WEATHER_PRIOR)

   !WE USE ONLY SMALL ECHO DEPTH VALUES IN THE BAYESIAN CLASIFICATION BUT WE OUTPUT ALL OF THEM FOR THE COMPUATATION OF THE 
   !STATISTICS.
   WHERE( tmp_data_3d(:,:,:,3) > ECHO_DEPTH_THRESHOLD ) !.AND. radar1%z - topography < 2000 )
      !Avoid using echo depth for tall storms near the surface.
      tmp_data_3d(:,:,:,3)=UNDEF
   ENDWHERE

   IF( COMPUTE_WEIGHT .AND. USE_ECHO_DEPTH)CALL GET_WEIGHT('echo_depth',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,3),WEATHER_PRIOR)
   IF( COMPUTE_WEIGHT .AND. USE_MAX_DBZ)CALL GET_WEIGHT('max_ref',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,4),WEATHER_PRIOR)
   IF( COMPUTE_WEIGHT .AND. USE_MAX_DBZ_Z)CALL GET_WEIGHT('max_ref_z',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,5),WEATHER_PRIOR)
   IF( COMPUTE_WEIGHT .AND. USE_REF_VGRAD)CALL GET_WEIGHT('ref_vgrad',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,6),WEATHER_PRIOR)
   
   !TODO GENERATE OUTPUT FOR 2D FIELDS.

DEALLOCATE( tmp_data_3d , tmp_data_2d )   
ENDIF
! --------------------------------------------------------------------------------

! Local minimum of local variance of dbz
IF( USE_LDBZVAR)THEN
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 2 ) )

  WRITE(6,*)'COMPUTING MINIMUM LOCAL VARIANCE OF DBZ'
  !Compute local variance.
  CALL BOX_FUNCTIONS_2D(reflectivity(:,:,:,nt),radar1%na,radar1%nr,radar1%ne,NXBOX_LDBZVAR,NYBOX_LDBZVAR,NZBOX_LDBZVAR,'SIGM',tmp_data_3d(:,:,:,2),0.0d0)

  !Compute the local minimum of the local variance.
  CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:,2),radar1%na,radar1%nr,radar1%ne,NXBOX_LDBZVAR,NYBOX_LDBZVAR,NZBOX_LDBZVAR,'MINN',tmp_data_3d(:,:,:,1),0.0d0) 

  IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('refminvar.grd',tmp_data_3d(:,:,:,2),reflectivity(:,:,:,nt))

  IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('refminvar.stat',tmp_data_3d(:,:,:,2),reflectivity(:,:,:,nt),timeout)

  IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('refminvar',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)
 

DEALLOCATE( tmp_data_3d )
ENDIF
! --------------------------------------------------------------------------------

! Texture of reflectivity field
IF( USE_TDBZ) THEN
   WRITE(6,*)'COMPUTING TEXTURE OF REFLECTIVITY'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 1) )
  
   CALL COMPUTE_TDBZ( reflectivity(:,:,:,nt),radar1%na,radar1%nr,radar1%ne,NXBOX_TDBZ,NYBOX_TDBZ,NZBOX_TDBZ,tmp_data_3d(:,:,:,1))

   !WHERE( reflectivity(:,:,:,nt) == UNDEF) tmp_data_3d(:,:,:,1) = UNDEF ! Keep only the valid gates.

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('tref.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('tref.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('tref',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)


DEALLOCATE( tmp_data_3d )
ENDIF

! SIGN (average sign of reflectivity change along a ray path)
IF( USE_SIGN ) THEN
   WRITE(6,*)'COMPUTING SIGN OF REFLECTIVITY'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 1) )

   CALL COMPUTE_SIGN( reflectivity(:,:,:,nt),radar1%na,radar1%nr,radar1%ne,NXBOX_SIGN,NYBOX_SIGN,NZBOX_SIGN,tmp_data_3d(:,:,:,1))

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('sign.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('sign.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('sign',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

! TSIGN (temporal sign, to detect coherent tendencies in reflectivity)
IF( USE_TSIGN ) THEN
   WRITE(6,*)'COMPUTING TEMPORAL SIGN OF REFLECTIIVTY'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 1) )

   CALL COMPUTE_TEMPORAL_SIGN( reflectivity(:,:,:,:),radar1%na,radar1%nr,radar1%ne,nt,NXBOX_TSIGN,NYBOX_TSIGN,NZBOX_TSIGN,tmp_data_3d(:,:,:,1))

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('tsign.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('tsign.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('tsign',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

IF( USE_RSPIN ) THEN
   WRITE(6,*)'COMPUTING REFLECTIVITY SPIN'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 1) )

   CALL COMPUTE_SPIN( reflectivity(:,:,:,nt),radar1%na,radar1%nr,radar1%ne,NXBOX_RSPIN,NYBOX_RSPIN,NZBOX_RSPIN,tmp_data_3d(:,:,:,1),SPIN_REFCHANGE_THRESHOLD)

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('rspin.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('rspin.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('rspin',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

IF( USE_TWA ) THEN
   WRITE(6,*)'COMPUTING TEMPORAL WIND AVERAGE'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 2) )

   CALL TIME_FUNCTIONS(wind,radar1%na,radar1%nr,radar1%ne,nt,'MEAN',tmp_data_3d(:,:,:,2))

   WHERE(tmp_data_3d(:,:,:,2) /= UNDEF)
     tmp_data_3d(:,:,:,2)=ABS(tmp_data_3d(:,:,:,2))
   ENDWHERE

   CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:,2),radar1%na,radar1%nr,radar1%ne,NXBOX_TWA,NYBOX_TWA,NZBOX_TWA,'MINN',tmp_data_3d(:,:,:,1),0.0d0)
  

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('twa.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('twa.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('twa',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

IF( USE_TWS ) THEN
   WRITE(6,*)'COMPUTING TEMPORAL WIND VARIANCE'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 1) )

   CALL TIME_FUNCTIONS(wind,radar1%na,radar1%nr,radar1%ne,nt,'TVAR',tmp_data_3d)

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('tws.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('tws.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('tws',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

IF( USE_TWC ) THEN
   WRITE(6,*)'COMPUTING TEMPORAL WIND CORRELATION'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 1) )

   CALL TIME_FUNCTIONS(wind,radar1%na,radar1%nr,radar1%ne,nt,'CORR',tmp_data_3d)

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('twc.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('twc.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('twc',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

!Temporal reflectivity correlation
IF( USE_TRC ) THEN
   WRITE(6,*)'COMPUTING TEMPORAL REFLECTIIVTY CORRELATION'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 1) )

   CALL TIME_FUNCTIONS(reflectivity,radar1%na,radar1%nr,radar1%ne,nt,'CORR',tmp_data_3d)

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('trc.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('trc.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('trc',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

!Temporal reflectivity correlation texture
IF( USE_TRCT ) THEN
   WRITE(6,*)'COMPUTING TEXTURE OF TEMPORAL REFLCTIVITY CORRELATION'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 2) )

   CALL TIME_FUNCTIONS(reflectivity,radar1%na,radar1%nr,radar1%ne,nt,'CORR',tmp_data_3d(:,:,:,2))
   CALL COMPUTE_TDBZ( tmp_data_3d(:,:,:,2),radar1%na,radar1%nr,radar1%ne,NXBOX_TRCT,NYBOX_TRCT,NZBOX_TRCT,tmp_data_3d(:,:,:,1))

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('trct.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('trct.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('trct',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF


!Temporal ref max std
IF( USE_TRMS) THEN
   WRITE(6,*)'COMPUTING LOCAL MAXIMUM OF TEMPORAL REFLECTIVITY VARIANCE'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 2) )
   !First compute temporal std
   CALL TIME_FUNCTIONS(reflectivity,radar1%na,radar1%nr,radar1%ne,nt,'TVAR',tmp_data_3d(:,:,:,2))

   CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:,2),radar1%na,radar1%nr,radar1%ne,NXBOX_TRMS,NYBOX_TRMS,NZBOX_TRMS,'MAXN',tmp_data_3d(:,:,:,1),0.0d0)

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('trms.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('trms.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)
 
   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('trms',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

!Temporal ref anomaly MSD (measures the diferen between and instantanesous field and the temporal average.
IF( USE_TRAM) THEN
   WRITE(6,*)'COMPUTE SQUARED DIFFERENCE OF THE TIME REFLECTIVITY ANOMALY'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 2) )
   !First compute temporal mean
   CALL TIME_FUNCTIONS(reflectivity,radar1%na,radar1%nr,radar1%ne,nt,'MEAN',tmp_data_3d(:,:,:,2))
   !Pick time closest to the center of the time window.
   center_index = nint( real(nt,r_size)/2.0d0 )
   WHERE(reflectivity(:,:,:,center_index) /= UNDEF)tmp_data_3d(:,:,:,2) =( tmp_data_3d(:,:,:,2) - reflectivity(:,:,:,center_index) )**2

   CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:,2),radar1%na,radar1%nr,radar1%ne,NXBOX_TRAM,NYBOX_TRAM,NZBOX_TRAM,'MEAN',tmp_data_3d(:,:,:,1),0.0d0)

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('tram.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('tram.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('tram',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

!Spatial ref anomaly MSD (measures the diference between and local field and the spatial average.
IF( USE_SRAM) THEN
   WRITE(6,*)'COMPUTE SQUARED DIFFERENCE OF THE SPATIAL REFLECTIVITY ANOMALY'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 2) )
   !First compute spatial average
   CALL BOX_FUNCTIONS_2D(reflectivity(:,:,:,nt),radar1%na,radar1%nr,radar1%ne,NXBOX_SRAM,NYBOX_SRAM,NZBOX_SRAM,'MEAN',tmp_data_3d(:,:,:,2),0.0d0)
   !Pick time closest to the center of the time window.
   DO ii = 1,radar1%na
     DO jj = 1,radar1%nr
       DO kk = 1,radar1%ne
          IF( tmp_data_3d(ii,jj,kk,2) /= UNDEF .AND. reflectivity(ii,jj,kk,nt) /= UNDEF )THEN
            tmp_data_3d(ii,jj,kk,2) = ( reflectivity(ii,jj,kk,nt) - tmp_data_3d(ii,jj,kk,2) )**2
          ELSE
            tmp_data_3d(ii,jj,kk,2)=UNDEF
          ENDIF
       ENDDO
     ENDDO
   ENDDO

   CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:,2),radar1%na,radar1%nr,radar1%ne,NXBOX_SRAM,NYBOX_SRAM,NZBOX_SRAM,'MEAN',tmp_data_3d(:,:,:,1),0.0d0)

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('sram.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('sram.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('sram',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

!Temporal wind anomaly MSD (measures the diference between and instantanesous field and the temporal average)
IF( USE_TWAM) THEN
   WRITE(6,*)'COMPUTE TIME WIND ANOMALY SQUARED DIFFERENCE'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 2) )
   !First compute temporal mean
   CALL TIME_FUNCTIONS(wind,radar1%na,radar1%nr,radar1%ne,nt,'MEAN',tmp_data_3d(:,:,:,2))
   !Pick time closest to the center of the time window.
   center_index = nint( real(nt,r_size)/2.0d0 )
   DO ii=1,radar1%na
     DO jj=1,radar1%nr
       DO kk=1,radar1%ne
         IF( tmp_data_3d(ii,jj,kk,2) /= UNDEF .AND. wind(ii,jj,kk,center_index) /= UNDEF)THEN
          tmp_data_3d(ii,jj,kk,2) = ( tmp_data_3d(ii,jj,kk,2) - wind(ii,jj,kk,center_index) )**2
         ELSE
          tmp_data_3d(ii,jj,kk,2)=UNDEF
         ENDIF
       ENDDO
     ENDDO
   ENDDO
   

   CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:,2),radar1%na,radar1%nr,radar1%ne,NXBOX_TWAM,NYBOX_TWAM,NZBOX_TWAM,'MEAN',tmp_data_3d(:,:,:,1),0.0d0)

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('twam.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('twam.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('twam',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

!Spatial ref anomaly MSD (measures the diference between local field and the spatial average.
IF( USE_SWAM) THEN
   WRITE(6,*)'COMPUTE THE WIND SPATIAL ANOMALY SQUARED DIFFERENCE'
ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 2) )
   !First compute spatial average
   CALL BOX_FUNCTIONS_2D(wind(:,:,:,nt),radar1%na,radar1%nr,radar1%ne,NXBOX_SWAM,NYBOX_SWAM,NZBOX_SWAM,'MEAN',tmp_data_3d(:,:,:,1),0.0d0)
   !Pick time closest to the center of the time window.
   DO ii = 1,radar1%na
     DO jj = 1,radar1%nr
       DO kk = 1,radar1%ne
          IF( tmp_data_3d(ii,jj,kk,2) /= UNDEF .AND. wind(ii,jj,kk,nt) /= UNDEF )THEN
            tmp_data_3d(ii,jj,kk,2) = ( wind(ii,jj,kk,nt) - tmp_data_3d(ii,jj,kk,2) )**2
          ELSE
            tmp_data_3d(ii,jj,kk,2)=UNDEF
          ENDIF
       ENDDO
     ENDDO
   ENDDO

   CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:,2),radar1%na,radar1%nr,radar1%ne,NXBOX_SWAM,NYBOX_SWAM,NZBOX_SWAM,'MEAN',tmp_data_3d(:,:,:,1),0.0d0)

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('swam.grd',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt))
   IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('swam.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)

   IF( COMPUTE_WEIGHT)CALL GET_WEIGHT('swam',W_WEATHER,WEIGHT_SUM,tmp_data_3d(:,:,:,1),WEATHER_PRIOR)

DEALLOCATE( tmp_data_3d )
ENDIF

!================================================================================
! End of parameter computation section
!================================================================================

!================================================================================
! Make a classification of echoes based on the parameters previously computed
!================================================================================
IF( COMPUTE_WEIGHT)THEN
  WRITE(6,*)"APPLIYING CLASSIFICATION"
  IF( WEIGHT_TYPE == 2 )THEN
   !Fuzzy logic, in this case normalize the weight before classifying the echoes
   WHERE( WEIGHT_SUM > 0 )
     W_WEATHER=W_WEATHER/WEIGHT_SUM
   ELSEWHERE
     W_WEATHER=WEATHER_PRIOR
   ENDWHERE
  ENDIF

  !Assign the clutter flag to the gates with probability of being weather lower than the selected threshold
  WHERE( W_WEATHER <= WEATHER_PROBABILITY_THRESHOLD .AND. reflectivity(:,:,:,nt) /=UNDEF  )QCFLAG=CODE_CLUTTER
ENDIF

IF( COMPUTE_WEIGHT .AND. USE_SPATIAL_RECLASSIFICATION )THEN
  WRITE(6,*)"PERFORMING SPATIAL RECLASSIFICATION"
  ALLOCATE( tmp_data_3d(radar1%na, radar1%nr , radar1%ne, 2) )
  tmp_data_3d(:,:,:,2)=W_WEATHER
  WHERE( reflectivity(:,:,:,nt) == UNDEF)tmp_data_3d(:,:,:,2)=UNDEF
  CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:,2),radar1%na,radar1%nr,radar1%ne,NXBOX_RC,NYBOX_RC,NZBOX_RC,'COUNT',tmp_data_3d(:,:,:,1),WEATHER_PROBABILITY_THRESHOLD)
  WHERE(tmp_data_3d(:,:,:,1) >= RECLASSIFICATION_THRESHOLD .AND. QCFLAG == CODE_CLUTTER)  
       QCFLAG=CODE_WEATHER_RECLASSIFIED
  ENDWHERE
  tmp_data_3d(:,:,:,2)=1.0d0-W_WEATHER
  CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:,2),radar1%na,radar1%nr,radar1%ne,NXBOX_RC,NYBOX_RC,NZBOX_RC,'COUNT',tmp_data_3d(:,:,:,1),1.0-WEATHER_PROBABILITY_THRESHOLD)
  WHERE(tmp_data_3d(:,:,:,1) >= RECLASSIFICATION_THRESHOLD .AND. QCFLAG /= CODE_CLUTTER)QCFLAG=CODE_CLUTTER_RECLASSIFIED
  DEALLOCATE(tmp_data_3d)
ENDIF

!================================================================================
! APPLY QC TO THE REFLECTIVITY AND WIND FIELDS
!================================================================================

WHERE( QCFLAG == CODE_CLUTTER .OR. QCFLAG == CODE_CLUTTER_RECLASSIFIED )
         qcedreflectivity(:,:,:)=UNDEF
         qcedwind(:,:,:)=UNDEF
ENDWHERE


!================================================================================
! APPLY ECHO_TOP AND ECHO_DEOPTH FILTERS
!================================================================================
!Some clutter usually remains after Bayesian classification. Echo top and echo
!depth can be useful to detect remaining clutter. 
IF( USE_ECHO_TOP_FILTER )THEN

  WHERE(echo_top /= UNDEF .AND. qcedreflectivity /=UNDEF .AND. echo_top < ECHO_TOP_FILTER_THRESHOLD )
       qcedreflectivity=UNDEF
       QCFLAG=CODE_ECHO_TOP_FILTER
  ENDWHERE
  WHERE(echo_top /= UNDEF .AND. echo_top < ECHO_TOP_FILTER_THRESHOLD )
       qcedwind=UNDEF
  ENDWHERE

ENDIF
IF( USE_ECHO_DEPTH_FILTER)THEN

  WHERE(echo_depth /= UNDEF .AND. qcedreflectivity /=UNDEF .AND. echo_depth < ECHO_DEPTH_FILTER_THRESHOLD )
       qcedreflectivity=UNDEF
       QCFLAG=CODE_ECHO_DEPTH_FILTER
  ENDWHERE
  WHERE(echo_depth /= UNDEF .AND. echo_depth < ECHO_DEPTH_FILTER_THRESHOLD )
       qcedwind=UNDEF
  ENDWHERE

ENDIF


! Speckle filter apply it again in case some noise remains in the reflectivity field after qc.
IF( USE_SPECKLE )CALL SPECKLE_FILTER(qcedreflectivity(:,:,:))

!================================================================================
! APPLY A RADIAL FILTER FOR THE REFLECTIVITY TO REMOVE NOISE
!================================================================================

IF( FILTER_REFLECTIVITY )THEN
WRITE(6,*)"FILTERING THE REFLECTIVITY"
ALLOCATE( tmp_data_3d(radar1%na,radar1%nr,radar1%ne,2) )

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ia,ie,mask)
 DO ia=1,radar1%na
  DO ie=1,radar1%ne
   mask=1
   WHERE( qcedreflectivity(ia,:,ie) == UNDEF )mask=0
   CALL filter_2d(qcedreflectivity(ia,:,ie),tmp_data_3d(ia,:,ie,1),mask,FILTER_REFLECTIVITY_LAMBDA,radar1%nr,1)
   qcedreflectivity(ia,:,ie)=tmp_data_3d(ia,:,ie,1)
  ENDDO
  WHERE( qcedreflectivity(ia,:,:) > MAX_REFLECTIVITY .OR. qcedreflectivity(ia,:,:) < MIN_REFLECTIVITY)
    qcedreflectivity(ia,:,:) = UNDEF
  ENDWHERE

 ENDDO
!$OMP END PARALLEL DO
DEALLOCATE( tmp_data_3d )
ENDIF



!================================================================================
! OUTPUT QCED DATA STATISTICS
!================================================================================

IF( DEBUG_OUTPUT .AND. COMPUTE_WEIGHT )THEN
    ALLOCATE( tmp_data_3d(radar1%na,radar1%nr,radar1%ne,2) )
    tmp_data_3d(:,:,:,2)=0.0d0
    IF(COMPUTE_WEIGHT )CALL WRITE_DEBUG_OUTPUT('weigth.grd',W_WEATHER,tmp_data_3d(:,:,:,2))
    tmp_data_3d(:,:,:,1)=REAL(QCFLAG,r_size)
    CALL WRITE_DEBUG_OUTPUT('qcflag.grd',tmp_data_3d(:,:,:,1),tmp_data_3d(:,:,:,2))
    CALL WRITE_DEBUG_OUTPUT('refqc.grd',qcedreflectivity(:,:,:),reflectivity(:,:,:,nt))
    CALL WRITE_DEBUG_OUTPUT('windqc.grd',qcedwind(:,:,:),reflectivity(:,:,:,nt))
  DEALLOCATE( tmp_data_3d )
ENDIF

IF( STATISTIC_OUTPUT .AND. COMPUTE_WEIGHT )THEN
   ALLOCATE(  tmp_data_3d(radar1%na,radar1%nr,radar1%ne,1) )
   tmp_data_3d(:,:,:,1)=REAL(QCFLAG,r_size)
   CALL WRITE_STATISTIC_OUTPUT('weigth.stat',W_WEATHER,reflectivity(:,:,:,nt),timeout)
   CALL WRITE_STATISTIC_OUTPUT('qcflag.stat',tmp_data_3d(:,:,:,1),reflectivity(:,:,:,nt),timeout)
   DEALLOCATE( tmp_data_3d )
ENDIF




!================================================================================
!  ESTIMATE ATTENUATION 
!================================================================================

 !Attenuation is computed after clutter is removed.
 IF(USE_ATTENUATION)THEN
   CALL GET_ATTENUATION(qcedreflectivity(:,:,:))
   IF(DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('attenuation.grd',attenuation,qcedreflectivity(:,:,:))
 ENDIF


RETURN
END SUBROUTINE RADAR_QC

SUBROUTINE COMPUTE_BLOCKING( ref , vr )
REAL(r_size), INTENT(INOUT) :: ref(radar1%na,radar1%nr,radar1%ne)  , vr(radar1%na,radar1%nr,radar1%ne)
REAL(r_size) :: alfa , beta , diag , max_vertical_extent(radar1%nr , radar1%ne )
REAL(r_size) :: vert_beam_width , beam_length , norm_h , min_norm_h , blocking_factor , correction
INTEGER      :: ii , jj , kk
REAL(r_size) :: lthreshold

IF( CORRECT_REFLECTIVITY )THEN !Correction will be applied
 lthreshold = 0.5d0 !To be consistent with the current correction scheme.
ELSE
 lthreshold = BLOCKING_THRESHOLD
ENDIF


!Compute beam height (in meters)
 beam_length=(radar1%rrange(2)-radar1%rrange(1))/2

DO kk=1,radar1%ne
 DO jj=1,radar1%nr
   vert_beam_width=radar1%beam_wid_v(1)*radar1%rrange(jj)*deg2rad/2
   alfa=atan(beam_length/vert_beam_width)
   diag =sqrt( beam_length**2 + vert_beam_width**2 )
   beta=alfa-radar1%elevation(kk)*deg2rad
   max_vertical_extent(jj,kk)=diag*cos(beta)
 ENDDO
ENDDO


!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ii,jj,kk,norm_h,min_norm_h,correction,blocking_factor)
DO ii=1,radar1%na
  DO kk=1,radar1%ne
     min_norm_h=1.0d0
     blocking_factor = 0.0d0
     correction=0.0d0
    DO jj=1,radar1%nr       
        !Compute heigth over the terrain normalized by the beam vertical extent.
        norm_h=( radar1%z(ii,jj,kk)-topography(ii,jj,kk) ) / max_vertical_extent(jj,kk) 
       IF( norm_h < min_norm_h )THEN 
          min_norm_h=norm_h
          IF( min_norm_h < 1.0d0  )THEN
            !We have some blocking, lets compute the blocking magnitude
            IF( min_norm_h > -1.0d0 )THEN
            blocking_factor=( min_norm_h * SQRT( 1 - min_norm_h ** 2) - ASIN( min_norm_h ) + PI/2 )/PI 
            ELSE
            blocking_factor=1.0d0
            ENDIF
              !write(6,*)blocking_factor,ii,jj,kk,topography(ii,jj,kk),norm_h
              !Compute correction 
              IF( CORRECT_REFLECTIVITY ) THEN
                IF( blocking_factor > 0.1d0 .AND. blocking_factor <= 0.3d0 )THEN
                   correction=1.0d0
                ELSEIF( blocking_factor > 0.3d0 .AND. blocking_factor <= 0.4d0 )THEN
                   correction=2.0d0
                ELSEIF( blocking_factor > 0.4d0 .AND. blocking_factor <= 0.5d0 )THEN   
                   correction=3.0d0
                ENDIF 
              ENDIF
          ENDIF
       ENDIF

       !If the amount of blocking is over the threshold then eliminate all the remaining beam.
       IF( blocking_factor >= lthreshold ) THEN
         ref(ii,jj:radar1%nr,kk)=UNDEF
         vr(ii,jj:radar1%nr,kk)=UNDEF
         qcflag(ii,jj:radar1%nr,kk)=CODE_BLOCKING
         EXIT !We are done for this beam
       ENDIF  
       IF( CORRECT_REFLECTIVITY .AND. correction > 0.0d0)THEN
             ref(ii,jj,kk)=ref(ii,jj,kk)+correction
             QCFLAG(ii,jj,kk)=CODE_BLOCKING_CORRECTED
       ENDIF
   ENDDO
  ENDDO
ENDDO
!$OMP END PARALLEL DO


RETURN
END SUBROUTINE COMPUTE_BLOCKING

SUBROUTINE READ_TOPOGRAPHY()
INTEGER                    :: ie , iolen , irec
REAL(r_sngl)               :: bufr(radar1%na,radar1%nr)

  INQUIRE(IOLENGTH=iolen) iolen
  OPEN(UNIT=33,FILE=terrain_file,FORM='UNFORMATTED',ACCESS='DIRECT',RECL=iolen*radar1%na*radar1%nr)
  irec=0
  DO ie = 1,radar1%ne
    irec=irec+1
    READ(33,rec=irec)bufr
    topography(:,:,ie)=REAL(bufr,r_size)
  ENDDO
  CLOSE(33)

RETURN
END SUBROUTINE READ_TOPOGRAPHY

SUBROUTINE WRITE_DEBUG_OUTPUT(filename,field,mask_real)
CHARACTER(*), INTENT(IN) :: filename
REAL(r_size), INTENT(IN) :: field(radar1%na,radar1%nr,radar1%ne)
REAL(r_sngl)             :: bufr(radar1%na,radar1%nr)
REAL(r_size), INTENT(IN) :: mask_real(radar1%na,radar1%nr,radar1%ne)
INTEGER , PARAMETER      :: IUNIT=33
INTEGER                  :: ia , ir , ie , iolen , irec
REAL(r_sngl)             :: wout(4)

    OPEN(UNIT=IUNIT,FILE=filename,FORM='UNFORMATTED',ACCESS='SEQUENTIAL')
    DO ie=1,radar1%ne
      bufr(:,:)=REAL(field(:,:,ie),r_sngl)
      WHERE( mask_real(:,:,ie) == UNDEF ) bufr = UNDEF
      WRITE(IUNIT)bufr
    ENDDO
    CLOSE(IUNIT)

RETURN
END SUBROUTINE WRITE_DEBUG_OUTPUT


SUBROUTINE WRITE_STATISTIC_OUTPUT(filename,field,mask_real,it)
CHARACTER(*), INTENT(IN) :: filename
INTEGER(8)  , INTENT(IN) :: it 
REAL(r_size), INTENT(IN) :: field(radar1%na,radar1%nr,radar1%ne)
REAL(r_size), INTENT(IN) :: mask_real(radar1%na,radar1%nr,radar1%ne)
INTEGER , PARAMETER      :: IUNIT=33
INTEGER                  :: ia , ir , ie  , icount , iundefcount
REAL(r_sngl)             :: wout(4)

ICOUNT=0
IUNDEFCOUNT=0
OPEN(UNIT=IUNIT,FILE=filename,FORM='UNFORMATTED',ACCESS='SEQUENTIAL',POSITION='APPEND')

     DO ia=1,radar1%na,SKIP_AZ
       DO ir=1,radar1%nr,SKIP_R
         DO ie=1,ELEVMAX, SKIP_ELEV
            IF( mask_real(ia,ir,ie) /= UNDEF  )THEN
              ICOUNT=ICOUNT+1
              wout(1)=REAL(field(ia,ir,ie),r_sngl)
              wout(2)=REAL(ia,r_sngl)
              wout(3)=REAL(ir,r_sngl)
              wout(4)=REAL(ie,r_sngl)
              WRITE(IUNIT)wout,it
              !IF( field(ia,ir,ie) == UNDEF)THEN
              !  IUNDEFCOUNT=IUNDEFCOUNT+1
              !ENDIF
            ENDIF
         ENDDO
       ENDDO
     ENDDO
    CLOSE(IUNIT)
    !WRITE(*,*)ICOUNT,' ITEMS WRITTEN TO FILE'
    !WRITE(*,*)IUNDEFCOUNT,' VALUES DETECTED'

RETURN
END SUBROUTINE WRITE_STATISTIC_OUTPUT

SUBROUTINE COUNT_UNDEF(field,fieldstr)
CHARACTER(*) :: fieldstr
REAL(r_size), INTENT(IN) :: field(radar1%na,radar1%nr,radar1%ne)
INTEGER                  :: ia , ir , ie  , icount

    ICOUNT=0
     DO ia=1,radar1%na,SKIP_AZ
       DO ir=1,radar1%nr,SKIP_R
         DO ie=1,ELEVMAX,SKIP_ELEV
            IF( field(ia,ir,ie) == UNDEF  )THEN
              ICOUNT=ICOUNT+1
            ENDIF
         ENDDO
       ENDDO
     ENDDO
    WRITE(*,*)'The field ',fieldstr,' has ',ICOUNT,' undef values'

RETURN
END SUBROUTINE COUNT_UNDEF


SUBROUTINE WRITE_STATISTIC_OUTPUT_2D(filename,field,mask_real)
CHARACTER(*), INTENT(IN) :: filename
REAL(r_size), INTENT(IN) :: field(radar1%na,radar1%nr,radar1%ne)
REAL(r_size), INTENT(IN) :: mask_real(radar1%na,radar1%nr,radar1%ne)
INTEGER , PARAMETER      :: IUNIT=33
INTEGER                  :: ia , ir , ie , iolen , irec
REAL(r_sngl)             :: wout(5)

INQUIRE(IOLENGTH=iolen) iolen
irec=0
    OPEN(UNIT=IUNIT,FILE=filename,FORM='UNFORMATTED',ACCESS='DIRECT',POSITION='APPEND',RECL=iolen*5)
     DO ia=1,radar1%na
       DO ir=1,radar1%nr
         DO ie=1,radar1%ne
            IF( mask_real(ia,ir,ie) /= UNDEF  )THEN
              wout(1)=REAL(field(ia,ir,ie),r_sngl)
              wout(2)=REAL(ia,r_sngl)
              wout(3)=REAL(ir,r_sngl)
              wout(4)=REAL(ie,r_sngl)
              wout(5)=REAL(timeout,r_sngl)
              !wout(6)=REAL(mask_real(ia,ir,ie),r_sngl)
              irec=irec+1
              WRITE(IUNIT,REC=irec)wout
            ENDIF
         ENDDO
       ENDDO
     ENDDO
    CLOSE(IUNIT)
RETURN
END SUBROUTINE WRITE_STATISTIC_OUTPUT_2D

SUBROUTINE SPECKLE_FILTER(var)
IMPLICIT NONE
REAL(r_size),INTENT(INOUT) :: var(radar1%na,radar1%nr,radar1%ne)
REAL(r_size)               :: tmp_data_3d(radar1%na,radar1%nr,radar1%ne)
INTEGER                    :: ia,ir,ie

WRITE(6,*)'COMPUTING SPECKLE FILTER'
  !Compute local variance.
  CALL BOX_FUNCTIONS_2D(var,radar1%na,radar1%nr,radar1%ne,NXBOX_SPECKLE,NYBOX_SPECKLE,NZBOX_SPECKLE,'COUN',tmp_data_3d,SPECKLE_REFLECTIVITY_THRESHOLD)

   IF( DEBUG_OUTPUT)CALL WRITE_DEBUG_OUTPUT('speckle.grd',tmp_data_3d,var)
   !IF( STATISTIC_OUTPUT)CALL WRITE_STATISTIC_OUTPUT('speckle.stat',tmp_data_3d,var,timeout)

    DO ia=1,radar1%na
      DO ir=1,radar1%nr
        DO ie=1,radar1%ne
           IF( var(ia,ir,ie) /= UNDEF .AND. tmp_data_3d(ia,ir,ie) < SPECKLE_THRESHOLD )THEN
             QCFLAG(ia,ir,ie) = CODE_SPECKLE
             var(ia,ir,ie) = UNDEF
           ENDIF
        ENDDO
      ENDDO
    ENDDO


RETURN
END SUBROUTINE SPECKLE_FILTER


SUBROUTINE GET_ATTENUATION(var)
IMPLICIT NONE
REAL(r_size),INTENT(INOUT) :: var(radar1%na,radar1%nr,radar1%ne) !Input reflectivity
REAL(r_size)               :: tmp_data_3d(radar1%na,radar1%nr,radar1%ne)
INTEGER                    :: ia,ir,ie
REAL(r_size)               :: beam_length , power(2) , mean_k

beam_length=radar1%rrange(2)-radar1%rrange(1)

ATTENUATION(:,1,:)=1.0d0

tmp_data_3d=10**(var/10.0d0)

WRITE(6,*)'COMPUTING ATTENUATION'

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ia,ie,ir,power,mean_k)
    DO ia=1,radar1%na
     DO ie=1,radar1%ne
      DO ir=1,radar1%nr-1
         IF(var(ia,ir,ie) /= UNDEF)THEN
           power(1)=10**(var(ia,ir,ie)/10.0d0)
         ELSE
           power(1)=0.0d0
         ENDIF
         IF(var(ia,ir+1,ie) /= UNDEF)THEN
           power(2)=10**(var(ia,ir+1,ie)/10.0d0)
         ELSE
           power(2)=0.0d0
         ENDIF
           mean_k=(1.0d-3*(a_coef/2)*(power(1)**b_coef+power(2)**b_coef))  !Compute mean k between ir and ir+1 (k is dbz/m);
           ATTENUATION(ia,ir+1,ie)=ATTENUATION(ia,ir,ie)*exp(-0.46d0*mean_k*beam_length)*calibration_error

      ENDDO
     ENDDO
    ENDDO
!$OMP END PARALLEL DO

RETURN
END SUBROUTINE GET_ATTENUATION


SUBROUTINE COMPUTE_TDBZ(var,na,nr,ne,nxbox,nybox,nzbox,texture)
!This routine performs the radar QC computing the requested fields.
IMPLICIT NONE
INTEGER     ,INTENT(IN) :: na , nr , ne    !Grid dimension
INTEGER     ,INTENT(IN) :: nxbox , nybox , nzbox  !Box dimension
REAL(r_size),INTENT(IN)  :: var(na,nr,ne) 
REAL(r_size),INTENT(OUT) :: texture(na,nr,ne)
REAL(r_size)             :: tmp_data_3d(na,nr,ne) 
INTEGER                  :: ii , jj , kk

!Compute the difference along the radial direction.
tmp_data_3d=UNDEF

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ii,jj,kk)
 DO ii = 1,na
   DO jj = 1 ,nr-1
     DO kk = 1, ne
        IF( var(ii,jj,kk) /= UNDEF .AND. var(ii,jj+1,kk) /= UNDEF)THEN
          tmp_data_3d(ii,jj,kk) = ( var(ii,jj+1,kk)-var(ii,jj,kk) )**2
        ENDIF
     ENDDO
   ENDDO
 ENDDO 
!$OMP END PARALLEL DO

 !Average the squared radial differences.
 CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:),na,nr,ne,nxbox,nybox,nzbox,'MEAN',texture,0.0d0)

RETURN
END SUBROUTINE COMPUTE_TDBZ

SUBROUTINE COMPUTE_SIGN(var,na,nr,ne,nxbox,nybox,nzbox,varsign)
!This routine computes the sign parameter
!Kessinger et al 2003
IMPLICIT NONE
INTEGER     ,INTENT(IN) :: na , nr , ne    !Grid dimension
INTEGER     ,INTENT(IN) :: nxbox , nybox , nzbox  !Box dimension
REAL(r_size),INTENT(IN)  :: var(na,nr,ne) 
REAL(r_size),INTENT(OUT) :: varsign(na,nr,ne)
REAL(r_size)             :: tmp_data_3d(na,nr,ne) , diff
INTEGER                  :: ii , jj , kk

!Compute the difference along the radial direction.
tmp_data_3d=UNDEF

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ii,jj,kk,diff)
 DO ii = 1,na
   DO jj = 1 ,nr-1
     DO kk = 1, ne
        IF( var(ii,jj,kk) /= UNDEF .AND. var(ii,jj+1,kk) /= UNDEF)THEN
           diff= var(ii,jj,kk) - var(ii,jj+1,kk) 
           IF( ABS(diff) > 0 )THEN
             tmp_data_3d(ii,jj,kk) = diff / ABS(diff)
           ELSE
             tmp_data_3d(ii,jj,kk) = 0.0d0
           ENDIF
        ENDIF
     ENDDO
   ENDDO
 ENDDO
!$OMP END PARALLEL DO

 !Average the squared radial differences.
 CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:),na,nr,ne,nxbox,nybox,nzbox,'MEAN',varsign,0.0d0)


RETURN
END SUBROUTINE COMPUTE_SIGN

SUBROUTINE COMPUTE_TEMPORAL_SIGN(var,na,nr,ne,nt,nxbox,nybox,nzbox,varsign)
!This routine computes the sign parameter
!Kessinger et al 2003
IMPLICIT NONE
INTEGER     ,INTENT(IN) :: na , nr , ne , nt   !Grid dimension
INTEGER     ,INTENT(IN) :: nxbox , nybox , nzbox  !Box dimension
REAL(r_size),INTENT(IN)  :: var(na,nr,ne,nt)
REAL(r_size),INTENT(OUT) :: varsign(na,nr,ne)
REAL(r_size)             :: tmp_data_3d(na,nr,ne) , diff
INTEGER                  :: ii , jj , kk , tt , nitems

!Compute the difference along the time direction.
tmp_data_3d=0

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ii,jj,kk,tt,diff,nitems)
 DO ii = 1,na
   DO jj = 1 ,nr
     DO kk = 1, ne
      nitems=0
      DO tt = 1, nt-1
        IF( var(ii,jj,kk,tt) /= UNDEF .AND. var(ii,jj,kk,tt+1) /= UNDEF)THEN
           nitems=nitems+1
           diff= var(ii,jj,kk,tt) - var(ii,jj,kk,tt+1)
           IF( ABS(diff) > 0 )THEN
             tmp_data_3d(ii,jj,kk) = tmp_data_3d(ii,jj,kk) + diff / ABS(diff)
           ENDIF
        ENDIF
     ENDDO
        IF( nitems > 0)THEN
          tmp_data_3d(ii,jj,kk)=tmp_data_3d(ii,jj,kk)/REAL(nitems,r_size)
        ELSE
          tmp_data_3d(ii,jj,kk)=UNDEF
        ENDIF

   ENDDO
 ENDDO
ENDDO
!$OMP END PARALLEL DO

 !Average the squared radial differences.
 CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:),na,nr,ne,nxbox,nybox,nzbox,'MEAN',varsign,0.0d0)


RETURN
END SUBROUTINE COMPUTE_TEMPORAL_SIGN


SUBROUTINE COMPUTE_SPIN(var,na,nr,ne,nxbox,nybox,nzbox,varspin,change_threshold)
!This routine computes the spin parameter
!Kessinger et al 2003 & Steiner and Smith 2002
!Kessinger et al 2002 suggested a change threshold of 11 dBz while
!Steiner and Smith suggested a threshold of 2 dBZ of course this may depend
!on the radar resolution.
IMPLICIT NONE
INTEGER     ,INTENT(IN) :: na , nr , ne    !Grid dimension
INTEGER     ,INTENT(IN) :: nxbox , nybox , nzbox  !Box dimension
REAL(r_size),INTENT(IN)  :: var(na,nr,ne) 
REAL(r_size),INTENT(IN)  :: change_threshold !Reflectivity threshold change
REAL(r_size),INTENT(OUT) :: varspin(na,nr,ne)
REAL(r_size)             :: vars(na,nr,ne)
REAL(r_size)             :: tmp_data_3d(na,nr,ne) , diff
INTEGER                  :: ii , jj , kk

!Compute the difference along the radial direction.
tmp_data_3d=UNDEF
varspin=UNDEF
 !Get spatially averaged variable (to compute threshold)
 CALL BOX_FUNCTIONS_2D(var,na,nr,ne,nxbox,nybox,nzbox,'MEAN',vars,0.0d0)

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ii,jj,kk,diff)
 DO kk=1,ne
   DO ii = 1 ,na
     DO jj = 2 , nr-1
        IF( var(ii,jj,kk) /= UNDEF .AND. var(ii,jj+1,kk) /= UNDEF)THEN
           diff= var(ii,jj,kk) - var(ii,jj+1,kk)
           IF( ABS(diff) > 0 )THEN
             tmp_data_3d(ii,jj,kk) = diff / ABS(diff)
           ELSE
             tmp_data_3d(ii,jj,kk) = 0.0d0
           ENDIF
        ENDIF
        IF ( tmp_data_3d(ii,jj,kk) /= UNDEF .AND. tmp_data_3d(ii,jj-1,kk) /= UNDEF )THEN
           IF( ABS( tmp_data_3d(ii,jj-1,kk)-tmp_data_3d(ii,jj,kk) ) >= change_threshold )THEN
              tmp_data_3d(ii,jj-1,kk)=1.0d0
           ELSE
              tmp_data_3d(ii,jj-1,kk)=0.0d0
           ENDIF
        ENDIF
     ENDDO
   ENDDO
 ENDDO
!$OMP END PARALLEL DO

 tmp_data_3d(:,1,:)=UNDEF
 tmp_data_3d(:,nr,:)=UNDEF

 !Average the squared radial differences.
 CALL BOX_FUNCTIONS_2D(tmp_data_3d(:,:,:),na,nr,ne,nxbox,nybox,nzbox,'COUN',varspin,0.5d0)


RETURN
END SUBROUTINE COMPUTE_SPIN



SUBROUTINE TIME_FUNCTIONS(var,na,nr,ne,nt,operation,output)
!This routine performs the radar QC computing the requested fields.
IMPLICIT NONE
CHARACTER(4),INTENT(IN) :: operation
INTEGER     ,INTENT(IN) :: na , nr , ne , nt    !Grid dimension
REAL(r_size),INTENT(IN)  :: var(na,nr,ne,nt) 
REAL(r_size),INTENT(OUT) :: output(na,nr,ne)
REAL(r_size)             :: tmp1,tmp2,tmp3,tmp4,tmp5
INTEGER                  :: ii,jj,kk,it,counter

!Compute the difference along the radial direction.
output=UNDEF

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ii,jj,kk,counter,tmp1,tmp2,tmp3,tmp4,tmp5)
 DO ii = 1,na
   DO jj = 1 ,nr
     DO kk = 1, ne


       IF  (TRIM(OPERATION) == 'COUN' )THEN
             tmp1=0.0d0
             DO it=1,nt
               IF( var(ii,jj,kk,it) /= UNDEF )THEN
                 tmp1=tmp1+1
                ENDIF
             ENDDO

             output(ii,jj,kk)=tmp1


       ELSEIF ( TRIM(OPERATION) == 'MEAN' )THEN
             !Mean
  

             tmp1=0.0d0
             counter=0
             DO it=1,nt
               IF( var(ii,jj,kk,it) /= UNDEF )THEN
                 tmp1=tmp1+var(ii,jj,kk,it)
                 counter=counter+1
                ENDIF
             ENDDO

             IF( counter >= 1)THEN
              tmp1=tmp1/REAL(counter,r_size)
              output(ii,jj,kk)=tmp1
             ENDIF


       ELSEIF( TRIM(OPERATION) == 'TVAR' )THEN
             !Standard deviation
             tmp1=0.0d0
             tmp2=0.0d0
             counter=0
             DO it=1,nt
               IF( var(ii,jj,kk,it) /= UNDEF )THEN
                 tmp1=tmp1+var(ii,jj,kk,it)
                 tmp2=tmp2+var(ii,jj,kk,it)**2
                 counter=counter+1
                ENDIF
             ENDDO

             IF( counter >= 2)THEN
              tmp1=tmp1/REAL(counter,r_size)
              tmp2=tmp2/REAL(counter,r_size)
         
              output(ii,jj,kk)=sqrt(tmp2-tmp1**2)    
             ENDIF
          
       ELSEIF( TRIM(OPERATION) == 'CORR' )THEN
             !Covariance
             tmp1=0.0d0
             tmp2=0.0d0
             tmp3=0.0d0
             tmp4=0.0d0
             tmp5=0.0d0
             counter=0
             DO it=1,nt
               IF( var(ii,jj,kk,it) /= UNDEF )THEN
                 tmp1=tmp1+var(ii,jj,kk,it)
                 tmp2=tmp2+REAL(it,r_size)
                 tmp3=tmp3+var(ii,jj,kk,it)*REAL(it,r_size)
                 tmp4=tmp4+var(ii,jj,kk,it)**2
                 tmp5=tmp5+REAL(it,r_size)**2
                 counter=counter+1
                ENDIF
             ENDDO 

             IF( counter >= 5)THEN
             tmp1=tmp1/REAL(counter,r_size)
             tmp2=tmp2/REAL(counter,r_size)
             tmp3=tmp3/REAL(counter,r_size)

             tmp3=tmp3-tmp1*tmp2
 
             tmp4=sqrt(tmp4/REAL(counter,r_size)-tmp1**2)
             tmp5=sqrt(tmp5/REAL(counter,r_size)-tmp2**2)

              IF( tmp4 > 0.0d0 .AND. tmp5 > 0.0d0 )THEN
                 output(ii,jj,kk)=tmp3 / (tmp4*tmp5)              
              ELSE
                 output(ii,jj,kk)=UNDEF
              ENDIF
            
             ENDIF 

       ENDIF
     ENDDO
   ENDDO
 ENDDO
!$OMP END PARALLEL DO


RETURN
END SUBROUTINE TIME_FUNCTIONS

SUBROUTINE BOX_FUNCTIONS_2D(datain,na,nr,ne,boxx,boxy,boxz,operation,dataout,threshold)

IMPLICIT NONE
INTEGER     ,INTENT(IN) :: na , nr , ne    !Grid dimension
INTEGER     ,INTENT(IN) :: boxx,boxy,boxz  !Box dimension
REAL(r_size),INTENT(IN) :: datain(na,nr,ne)
CHARACTER(4),INTENT(IN) :: operation     
REAL(r_size),INTENT(IN) :: threshold
REAL(r_size),INTENT(OUT) :: dataout(na,nr,ne) !Result
REAL(r_size),ALLOCATABLE :: tmp_field(:) 
REAL(r_size)             :: tmp_mean , tmp_var
INTEGER                  :: NITEMS
INTEGER                  :: ii , jj , kk , bii , bjj , bkk , box_size , iin ,ii_index , data_count
dataout=UNDEF

!WRITE(6,*)'HELLO FROM BOX_FUNCTIONS_2D, REQUESTED OPERATION IS ',operation
!WRITE(6,*)'BOX SIZE IS : NZ=',boxx,' NY=',boxy,' NZ=',boxz
!%To reduce memory size the computation will be done level by level.
box_size=(2*boxx+1)*(2*boxy+1)*(2*boxz+1);

ALLOCATE( tmp_field(box_size) )

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(kk,ii,jj,bkk,bii,bjj,ii_index,NITEMS,tmp_field,tmp_mean,tmp_var,data_count,iin)
DO kk=1,ne
 DO ii=1,na
  DO jj=1,nr
     NITEMS=0
     tmp_field=0.0d0
     DO bkk=kk-boxz,kk+boxz
       DO bii=ii-boxx,ii+boxx
         DO bjj=jj-boxy,jj+boxy
            IF( bkk >= 1 .AND. bkk <= ne .AND. bjj >= 1 .AND. bjj <= nr )THEN
              !Boundary condition in X
              ii_index=bii
              IF( bii < 1 )ii_index=bii+na
              IF( bii > na)ii_index=bii-na 
              IF( OPERATION == 'MEA2' .AND. bii== ii .AND. bjj==jj .AND. bkk==kk)CYCLE !We will not count the center of the box.
                NITEMS=NITEMS+1
                tmp_field(NITEMS)=datain(ii_index,bjj,bkk)
            ENDIF
         ENDDO
       ENDDO
      ENDDO 
      !Perform the operation and save the result in dataout
      IF( OPERATION .EQ. 'MEAN' .OR. OPERATION .EQ. 'MEA2' )THEN
        !Undef values won't be considered.
        data_count=0
        tmp_mean=0.0d0
        DO iin=1,NITEMS
          IF( tmp_field(iin) /= UNDEF )THEN
            data_count=data_count+1
            tmp_mean=tmp_mean+tmp_field(iin)
          ENDIF
        ENDDO
        IF( data_count .GT. 0)THEN
          dataout(ii,jj,kk)=tmp_mean/REAL(data_count,r_size)
        ENDIF
      ELSEIF( OPERATION == 'SIGM')THEN
        !Undef values won't be considered.
        tmp_mean=0.0d0
        tmp_var=0.0d0
        data_count=0
        DO iin=1,NITEMS
          IF( tmp_field(iin) .ne. UNDEF )THEN
            data_count=data_count+1
            tmp_mean=tmp_mean+tmp_field(iin)
            tmp_var=tmp_var+tmp_field(iin) ** 2
          ENDIF
        ENDDO
        IF( data_count .GT. 0)THEN
         tmp_mean=tmp_mean/REAL(data_count,r_size)
         tmp_var=tmp_var/REAL(data_count,r_size)
         dataout(ii,jj,kk)=SQRT(tmp_var - tmp_mean**2 )
        ENDIF

      ELSEIF( OPERATION == 'COUN')THEN
        !Count values over a certain threshold (note that undef values will be 
        !always below the threshold.
        tmp_mean=0.0d0
        DO iin=1,NITEMS
          IF( tmp_field(iin)  >= threshold .AND. tmp_field(iin) /= UNDEF )THEN
            tmp_mean=tmp_mean+1.0d0
          ENDIF
        ENDDO
        IF( NITEMS > 0)dataout(ii,jj,kk)=tmp_mean/REAL(NITEMS,r_size)

      ELSEIF( OPERATION == 'MAXN')THEN
        !Local maximum tacking care of undef values.
        tmp_mean=UNDEF
        DO iin=1,NITEMS
          IF( tmp_mean == UNDEF .AND. tmp_field(iin) /= UNDEF )tmp_mean=tmp_field(iin)
          IF( tmp_field(iin)  > tmp_mean .AND. tmp_mean /= UNDEF .AND. tmp_field(iin) /= UNDEF )THEN
            tmp_mean = tmp_field(iin)
          ENDIF
        ENDDO
        dataout(ii,jj,kk)=tmp_mean
      ELSEIF( OPERATION == 'MINN')THEN
        !Local maximum tacking care of undef values.
        tmp_mean=UNDEF
        DO iin=1,NITEMS
          IF( tmp_mean == UNDEF .AND. tmp_field(iin) /= UNDEF )tmp_mean=tmp_field(iin)
          IF( tmp_field(iin)  < tmp_mean .AND. tmp_mean /= UNDEF .AND. tmp_field(iin) /= UNDEF )THEN
            tmp_mean = tmp_field(iin)
          ENDIF
        ENDDO
        dataout(ii,jj,kk)=tmp_mean
      ENDIF
  ENDDO
 ENDDO
ENDDO 
!$OMP END PARALLEL DO

!WRITE(6,*)'FINISH PERFORMING 2D BOX FUNCTION OPERATION'

RETURN
END SUBROUTINE BOX_FUNCTIONS_2D

SUBROUTINE  COMPUTE_ECHO_TOP(reflectivity,heigth,rrange,na,nr,ne,output_data_3d,output_data_2d)
!Curretnly this routine:
!Compute 3D echo top, echo base , echo depth , max dbz and max dbz z
!Performs interpolation from original radar grid (r,elevation) to an uniform (r,z) grid, where
!the parameters are computed.
!Then the result is interpolated back to the original radar grid.

IMPLICIT NONE
INTEGER     ,INTENT(IN)  :: na,nr,ne
REAL(r_size),INTENT(IN)  :: reflectivity(na,nr,ne) , heigth(nr,ne) , rrange(nr,ne)  
REAL(r_size),INTENT(OUT) :: output_data_3d(na,nr,ne,NPAR_ECHO_TOP_3D)  !Echo top , echo base , echo depth , max_dbz , maz_dbz_z , vertical_z_gradient
REAL(r_size),INTENT(OUT) :: output_data_2d(na,nr,NPAR_ECHO_TOP_2D)  !Max echo top, max_echo_base, max_echo_depth, col_max, height weighted col_max
REAL(r_size) :: output_data_3d_2(na,nr,ne,NPAR_ECHO_TOP_3D)  !Echo top , echo base , echo depth , max_dbz , maz_dbz_z , vertical_z_gradient
REAL(r_size) :: output_data_2d_2(na,nr,NPAR_ECHO_TOP_2D)  !Max echo top, max_echo_base, max_echo_depth, col_max, height weighted col_max

!REAL(r_size)             :: tmp_output_data_3d(na,nr,ne,NPAR_ECHO_TOP_3D)
!-----> The following variables will be saved within calls
REAL(r_size), ALLOCATABLE,SAVE :: Z(:,:) , R(:,:) 
INTEGER, ALLOCATABLE,SAVE      :: REGJ(:,:,:) , REGI(:,:,:) , INVI(:,:,:) , INVJ(:,:,:) 
INTEGER, ALLOCATABLE,SAVE      :: NEARESTN(:,:) , INVNEARESTN(:,:)
REAL(r_size),ALLOCATABLE,SAVE  :: W(:,:,:),INVW(:,:,:)
INTEGER,SAVE                   :: REGNZ , REGNR
LOGICAL,SAVE                   :: INITIALIZED=.FALSE.
!----->
REAL(r_size), ALLOCATABLE      :: REGREF(:,:)
CHARACTER(4)                   :: OPERATION='MEAN'
INTEGER                        :: i, ii , jj , ia , ip 
REAL(r_size),ALLOCATABLE       :: tmp_data3d(:,:,:,:) , tmp_data3d_2(:,:,:,:) , tmp_data2d(:,:,:), tmp_data2d_2(:,:,:)

!WRITE(6,*)'HELLO FROM COMPUTE_ECHO_TOP'

!Perform this part only in the first call.
IF( .NOT. INITIALIZED )THEN

REGNZ=INT(MAX_Z_ECHO_TOP / DZ_ECHO_TOP)+1
REGNR=INT(MAX_R_ECHO_TOP / DX_ECHO_TOP)+1
!WRITE(6,*)'REGNZ = ',REGNZ,' REGNR = ',REGNR

ALLOCATE( Z(REGNR,REGNZ) , R(REGNR,REGNZ) )
ALLOCATE( REGI(REGNR,REGNZ,4) , REGJ(REGNR,REGNZ,4), NEARESTN(REGNR,REGNZ) )
ALLOCATE( INVI(nr,ne,4) , INVJ(nr,ne,4), INVNEARESTN(nr,ne) )
ALLOCATE( W(REGNR,REGNZ,4),INVW(nr,ne,4) )
!Set interpolation from range-elevation to range-z grid

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ii,jj)
DO ii=1,REGNR
 DO jj=1,REGNZ
    Z(ii,jj)=REAL(jj-1,r_size)*DZ_ECHO_TOP
    R(ii,jj)=REAL(ii-1,r_size)*DX_ECHO_TOP
    CALL com_xy2ij(nr,ne,rrange,heigth,R(ii,jj),Z(ii,jj),REGI(ii,jj,:),REGJ(ii,jj,:),W(ii,jj,:),NEARESTN(ii,jj))
  ENDDO
ENDDO
!$OMP END PARALLEL DO

!Set interpolation from range-z to range-elevation grid.
!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ii,jj)
DO ii=1,nr
 DO jj=1,ne
    CALL com_xy2ij(REGNR,REGNZ,R,Z,rrange(ii,jj),heigth(ii,jj),INVI(ii,jj,:),INVJ(ii,jj,:),INVW(ii,jj,:),INVNEARESTN(ii,jj)) 
  ENDDO
ENDDO
!$OMP END PARALLEL DO

ENDIF !End of first call only section.

ALLOCATE( tmp_data3d(na,REGNR,REGNZ,NPAR_ECHO_TOP_3D))
ALLOCATE( tmp_data3d_2(na,REGNR,REGNZ,NPAR_ECHO_TOP_3D))

ALLOCATE( tmp_data2d(na,REGNR,NPAR_ECHO_TOP_2D))
ALLOCATE( tmp_data2d_2(na,REGNR,NPAR_ECHO_TOP_2D))

ALLOCATE( REGREF(REGNR,REGNZ) )


tmp_data3d=UNDEF
tmp_data3d_2=UNDEF
!tmp_output_data_3d=UNDEF

output_data_3d=UNDEF
output_data_3d_2=UNDEF

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ia,ii,jj,REGREF)
DO ia=1,na
 REGREF=UNDEF
 !Interp reflectivity from elevation-range grid to z-range grid. (nearest neighbor)
 DO ii=1,REGNR
  DO jj=1,REGNZ 
     IF( NEARESTN(ii,jj) > 0)THEN
        REGREF(ii,jj)=reflectivity(ia,REGI(ii,jj,NEARESTN(ii,jj)),REGJ(ii,jj,NEARESTN(ii,jj)))
     ENDIF
  ENDDO

  CALL ECHO_TOP_SUB(REGREF(ii,:),Z(ii,:),REGNZ,tmp_data3d(ia,ii,:,:),tmp_data2d(ia,ii,:),MAX_ECHO_TOP_LEVS,DBZ_THRESHOLD_ECHO_TOP)

 ENDDO

 !----> DEBUG
 !IF(ia == 67)THEN
 !WRITE(*,*)REGNR,REGNZ
 !OPEN(34,FILE='slice.grd',FORM='unformatted',access='sequential')
 !WRITE(34)REAL(tmp_data3d(ia,:,:,6),r_sngl)
 !WRITE(34)REAL(REGREF(:,:),r_sngl)
 !ENDIF
 !----> DEBUG


ENDDO
!$OMP END PARALLEL DO


!DO ip=1,NPAR_ECHO_TOP_3D
!CALL BOX_FUNCTIONS_2D(tmp_data3d(:,:,:,1),na,REGNR,REGNZ,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,NZBOX_ECHO_TOP,'MEAN',tmp_data3d_2(:,:,:,1),0.0d0)
!CALL BOX_FUNCTIONS_2D(tmp_data3d(:,:,:,2),na,REGNR,REGNZ,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,NZBOX_ECHO_TOP,'MEAN',tmp_data3d_2(:,:,:,2),0.0d0)
!CALL BOX_FUNCTIONS_2D(tmp_data3d(:,:,:,3),na,REGNR,REGNZ,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,NZBOX_ECHO_TOP,'MEAN',tmp_data3d_2(:,:,:,3),0.0d0)
!CALL BOX_FUNCTIONS_2D(tmp_data3d(:,:,:,4),na,REGNR,REGNZ,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,NZBOX_ECHO_TOP,'MEAN',tmp_data3d_2(:,:,:,4),0.0d0)
!CALL BOX_FUNCTIONS_2D(tmp_data3d(:,:,:,5),na,REGNR,REGNZ,0,5,0,'MINN',tmp_data3d_2(:,:,:,5),0.0d0)
!CALL BOX_FUNCTIONS_2D(tmp_data3d(:,:,:,6),na,REGNR,REGNZ,0,5,0,'MINN',tmp_data3d_2(:,:,:,6),0.0d0)
!END DO

!DO ip=1,NPAR_ECHO_TOP_2D
!CALL BOX_FUNCTIONS_2D(tmp_data2d(:,:,ip),na,REGNR,1,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,0,'MEAN',tmp_data2d_2(:,:,ip),0.0d0)
!END DO


!Interpolate back to the elevation-range grid. (Using nearest neighbor)

!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ia,ii,jj)
DO ia=1,na
 DO ii=1,nr
  DO jj=1,ne
    IF( INVNEARESTN(ii,jj) .GT. 0 )THEN
      output_data_3d_2(ia,ii,jj,:)=tmp_data3d(ia,INVI(ii,jj,INVNEARESTN(ii,jj)),INVJ(ii,jj,INVNEARESTN(ii,jj)),:)
    ENDIF
    IF( output_data_3d(ia,ii,jj,5) /= UNDEF)THEN
      output_data_3d_2(ia,ii,jj,5)=output_data_3d(ia,ii,jj,5)-topography(ia,ii,jj)
    ENDIF
  ENDDO
    IF( INVNEARESTN(ii,1) .GT. 0 )THEN !We interpolate the data to the lowest level.
      output_data_2d_2(ia,ii,:)=tmp_data2d(ia,INVI(ii,1,INVNEARESTN(ii,1)),:)
    ENDIF
 ENDDO

 !We will use the vertical reflectivity gradient and maximum ref height over the terrain only for heights between 0 and 3 km
 WHERE( heigth - topography(ia,:,:) < 0 .OR. heigth - topography(ia,:,:) > ECHO_DEPTH_THRESHOLD )
      output_data_3d_2(ia,:,:,6)=UNDEF
      output_data_3d_2(ia,:,:,5)=UNDEF
 ENDWHERE


ENDDO   
!$OMP END PARALLEL DO

CALL BOX_FUNCTIONS_2D(output_data_3d_2(:,:,:,1),radar1%na,radar1%nr,radar1%ne,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,NZBOX_ECHO_TOP,'MEAN',output_data_3d(:,:,:,1),0.0d0)
CALL BOX_FUNCTIONS_2D(output_data_3d_2(:,:,:,2),radar1%na,radar1%nr,radar1%ne,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,NZBOX_ECHO_TOP,'MEAN',output_data_3d(:,:,:,2),0.0d0)
CALL BOX_FUNCTIONS_2D(output_data_3d_2(:,:,:,3),radar1%na,radar1%nr,radar1%ne,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,NZBOX_ECHO_TOP,'MEAN',output_data_3d(:,:,:,3),0.0d0)
CALL BOX_FUNCTIONS_2D(output_data_3d_2(:,:,:,4),radar1%na,radar1%nr,radar1%ne,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,NZBOX_ECHO_TOP,'MEAN',output_data_3d(:,:,:,4),0.0d0)
CALL BOX_FUNCTIONS_2D(output_data_3d_2(:,:,:,5),radar1%na,radar1%nr,radar1%ne,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,NZBOX_ECHO_TOP,'MEAN',output_data_3d(:,:,:,5),0.0d0)
CALL BOX_FUNCTIONS_2D(output_data_3d_2(:,:,:,6),radar1%na,radar1%nr,radar1%ne,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,NZBOX_ECHO_TOP,'MEAN',output_data_3d(:,:,:,6),0.0d0)

DO ip=1,NPAR_ECHO_TOP_2D
CALL BOX_FUNCTIONS_2D(output_data_2d_2(:,:,ip),radar1%na,radar1%nr,1,NXBOX_ECHO_TOP,NYBOX_ECHO_TOP,0,'MEAN',output_data_2d(:,:,ip),0.0d0)
END DO

DEALLOCATE( tmp_data3d_2 , tmp_data3d )
DEALLOCATE( REGREF )


INITIALIZED=.TRUE.
RETURN
END SUBROUTINE COMPUTE_ECHO_TOP

SUBROUTINE ECHO_TOP_SUB(reflectivity,z,nz,output_3d,output_2d,max_levs,threshold)
!Vertical columns calculations
!Compute the possition of multiple echo tops in a single reflectivity column.
!Compute echo depth of each echo layer
!compute echo base
!compute max dbz
!This routine returns a vertical profile of echo base, echo top , echo depth , max dbz and max dbz a fore 
!each cloud layer.
!It also returns the vertical profile of the vertical gradient of the reflectivity field.

IMPLICIT NONE
INTEGER, INTENT(IN)  :: nz , max_levs
REAL(r_size),INTENT(IN) :: reflectivity(nz) , z(nz)
REAL(r_size),INTENT(OUT):: output_3d(nz,6) !echo_top, echo_base, echo_depth , max_dbz , max_dbz_z , reflectivity gradient
REAL(r_size),INTENT(OUT):: output_2d(7) !Max echo top, max_echo_base, max_echo_depth, col_max, height weighted col_max , first ref maximum height , intensity.

REAL(r_size),INTENT(IN) :: threshold    !Reflectivity threshold to detect echo top.
INTEGER, PARAMETER      :: Nlevelstop=2
REAL(r_size)            :: tmp(max_levs,5) !echo_top, echo_base, echo_depth , max_dbz , max_dbz_z
REAL(r_size)            :: ref(nz) , ave_ref , sum_z
INTEGER                 :: jj, iz , base_count , top_count , tmp_count , itop , imax
LOGICAL                 :: base_detected , top_detected
LOGICAL                 :: found_first_maximum
REAL(r_size), PARAMETER :: first_maximum_threshold = 10.0d0 
INTEGER     , PARAMETER :: NDELTAZ=30      ! NDELTAZ * dz is the distance used to estimate vertical reflectivity gradient
REAL(r_size), PARAMETER :: refmin =0.0d0  ! Reflectivity value that will be assumed for UNDEF values in gradient computation.
                                          

output_3d=UNDEF
output_2d=UNDEF
tmp=UNDEF

base_count=0
top_count=0

ref=reflectivity   !reflectivity is intent in.


base_detected=.false.
top_detected=.false.

!Before computation extend data one or to levels below the first echo. This is done to prevent the first level to fall outside the computation
!of these scores.
DO iz=1,nz
   IF( z(iz) > 3000 )EXIT

   IF( ref(iz) /= UNDEF )THEN
      IF( iz>= 2)THEN
       ref(iz-1)=ref(iz)
      ENDIF

     EXIT
   ENDIF
ENDDO


DO iz=1,nz
   !Look for an echo base
   IF( ref(iz) > threshold .AND.  .NOT. base_detected .AND. ref(iz) /= UNDEF )THEN
       !An echo base has been detected.
       IF( base_count < max_levs)THEN
       base_detected=.true.
       top_detected=.false.
       base_count=base_count+1
       tmp(base_count,2)=z(iz)   !Echo base
       tmp(base_count,4)=ref(iz) !Max dbz
       tmp(base_count,5)=z(iz)   !Max dbz_z
       ENDIF
   ENDIF
   !Look for an echo top.
   IF( iz > Nlevelstop )THEN
     tmp_count=0
     DO jj=iz-Nlevelstop+1,iz
        IF( ref(jj) < threshold .OR. ref(jj) == UNDEF )tmp_count=tmp_count+1
     ENDDO
     IF( tmp_count == Nlevelstop .AND. .NOT. top_detected .AND. base_detected )THEN
     !An echo top has been detected
        top_detected=.true.
        base_detected=.false.
        IF( base_count <= max_levs )THEN
           tmp(base_count,1)=z(iz-Nlevelstop)  !Echo top
        ENDIF
     ENDIF
   ENDIF
   !Echo top associated with top of the radar domain.
   IF( iz == nz .AND. base_detected .AND. .NOT. top_detected )THEN
   !Domain is over but echo top has not been found! :( 
   !Force echo top
       IF( base_count <= max_levs )THEN
           tmp(base_count,1)=z(iz)  !Echo top
       ENDIF
   ENDIF
   !Compute max dbz
   IF( base_detected .AND. .NOT. top_detected .AND. ref(iz) /=UNDEF )THEN
       !We are within a cloud or an echo region. Compute max dbz.
       IF( ref(iz) > tmp(base_count,4) )THEN  !Max dbz
           tmp(base_count,4)=ref(iz)  !Max dbz
           tmp(base_count,5)=z(iz)    !Max dbz z
       ENDIF
   ENDIF
   !Compute vertical gradient of reflectivity.
   IF( iz <= nz-NDELTAZ)THEN
   IF( ref(iz) /= UNDEF )THEN
    IF(  ref( iz + NDELTAZ ) /= UNDEF )THEN
        output_3d(iz,6)= ( ref(iz+NDELTAZ) - ref(iz) ) /( z(iz+NDELTAZ) - z(iz) )
    ELSE
        output_3d(iz,6)= ( refmin          - ref(iz) ) /( z(iz+NDELTAZ) - z(iz) )
    ENDIF
   ENDIF
   ENDIF


ENDDO !End for loop over levels

DO itop=1,max_levs
   IF( tmp(itop,1) .NE. UNDEF  .AND.  tmp(itop,2) .NE. UNDEF )THEN  !Echo top and echo base
       DO iz=1,nz-1
          IF( z(iz) >= tmp(itop,2) .AND. z(iz) <= tmp(itop,1))THEN
               output_3d(iz,1:2)=tmp(itop,1:2)
               output_3d(iz,3)  =tmp(itop,1)-tmp(itop,2)
               output_3d(iz,4:5)=tmp(itop,4:5)
          ENDIF
          IF( z(iz) > tmp(itop,1) )EXIT
       ENDDO
   ENDIF
   !Find maximum echo top
   IF ( tmp(itop,1) .NE. UNDEF )THEN
      IF( output_2d(1) .EQ. UNDEF )THEN
        output_2d(1)=tmp(itop,1)
        ELSE
         IF( tmp(itop,1) >= output_2d(1) )THEN
           output_2d(1) = tmp(itop,1)
         ENDIF
      ENDIF
   ENDIF

   !Find maximum echo base
   IF ( tmp(itop,2) .NE. UNDEF )THEN
      IF( output_2d(2) .EQ. UNDEF )THEN
        output_2d(2)=tmp(itop,2)
        ELSE
         IF( tmp(itop,2) >= output_2d(2) )THEN
           output_2d(2) = tmp(itop,2)
         ENDIF
      ENDIF
   ENDIF

   !Find maximum echo depth
   IF ( tmp(itop,3) .NE. UNDEF )THEN
      IF( output_2d(3) .EQ. UNDEF )THEN
        output_2d(3)=tmp(itop,3)
        ELSE
         IF( tmp(itop,3) >= output_2d(3) )THEN
           output_2d(3) = tmp(itop,3)
         ENDIF
      ENDIF
   ENDIF

   !Find maximum reflectivity (colmax)
   IF ( tmp(itop,4) .NE. UNDEF )THEN
      IF( output_2d(4) .EQ. UNDEF )THEN
        output_2d(4)=tmp(itop,4)
        ELSE
         IF( tmp(itop,4) >= output_2d(4) )THEN
           output_2d(4) = tmp(itop,4)
         ENDIF
      ENDIF
   ENDIF

   IF ( tmp(itop,4) .NE. UNDEF )THEN
      IF( output_2d(4) .EQ. UNDEF )THEN
        output_2d(4)=tmp(itop,4)
        ELSE
         IF( tmp(itop,4) >= output_2d(4) )THEN
           output_2d(4) = tmp(itop,4)
         ENDIF
      ENDIF
   ENDIF

ENDDO


!Compute heigh weigthed averaged reflectivity, the height of the first reflectivity maximum and its intensity.


ave_ref=0
sum_z=0
found_first_maximum=.FALSE.
imax=0
DO iz=1,nz

 IF( reflectivity(iz) .NE. UNDEF )THEN
   ave_ref = z(iz) * reflectivity(iz)
   sum_z   = z(iz)
 ENDIF

 IF( reflectivity(iz) /= UNDEF .AND. output_2d(7) == UNDEF )THEN
   output_2d(7) = reflectivity(iz)    !Intensity of first reflectivity maximun
   output_2d(6) = z(iz)               !Height of first reflectivity maximum
 ENDIF
 IF( reflectivity(iz) /= UNDEF .AND. (reflectivity(iz) - output_2d(7)) < first_maximum_threshold .AND. .NOT. found_first_maximum )THEN
   found_first_maximum=.TRUE. 
 ELSE
   IF( reflectivity(iz) > output_2d(6) )THEN
     output_2d(7) = reflectivity(iz) !Keep updating the maximum until we reach the first maximum.
     output_2d(6) = z(iz)            !Keep updating the height of the maximum 
   ENDIF
 ENDIF

ENDDO
IF( sum_z .GT. 0 )THEN
  output_2d(5) = ave_ref / sum_z
ELSE
  output_2d(5) = 0
ENDIF

!Max echo top, max_echo_base, max_echo_depth, col_max, height weighted col_max
RETURN
END SUBROUTINE ECHO_TOP_SUB


!-----------------------------------------------------------------------
! (X,Y) --> (i,j) conversion (General pourpuse interpolation)
!   [ORIGINAL AUTHOR:] Masaru Kunii
!-----------------------------------------------------------------------
SUBROUTINE com_xy2ij(nx,ny,fx,fy,datax,datay,dist_min_x,dist_min_y,ratio,nearestn)
  IMPLICIT NONE
  ! --- inout variables
  INTEGER,INTENT(IN) :: nx,ny !number of grid points
  REAL(r_size),INTENT(IN) :: fx(nx,ny),fy(nx,ny) !(x,y) at (i,j)
  REAL(r_size),INTENT(IN) :: datax,datay !target (lon,lat)
  ! --- local work variables
  INTEGER,PARAMETER :: detailout = .FALSE.
  INTEGER,PARAMETER :: num_grid_ave = 4  ! fix
  INTEGER :: ix,jy,ip,wk_maxp
  INTEGER :: iorder_we,iorder_sn
  INTEGER :: nxp,nyp
  INTEGER,PARAMETER :: order = 2
  REAL(r_size),PARAMETER :: max_dist = 2.0e+6
  REAL(r_size) :: rxmax, rxmin, rymax, rymin   
  REAL(r_size) :: dist(num_grid_ave)  , tmp_dist(num_grid_ave)
  INTEGER,INTENT(OUT) :: dist_min_x( num_grid_ave)
  INTEGER,INTENT(OUT) :: dist_min_y( num_grid_ave) 
  INTEGER,INTENT(OUT) :: nearestn(1)
  REAL(r_size) :: wk_dist, sum_dist
  REAL(r_size),INTENT(OUT) :: ratio(num_grid_ave)
  
  IF(detailout) THEN
    WRITE(6,'(A)') '====================================================='
    WRITE(6,'(A)') '      Detailed output of SUBROUTINE com_pos2ij       '
    WRITE(6,'(A)') '====================================================='    
  END IF
  ! ================================================================
  !   Check the Order of fx,fy 
  ! ================================================================   
  iorder_we = 1
  iorder_sn = 1
  IF(fx(1,1) > fx(2,1)) THEN
    iorder_we = -1
  END IF
  IF(fy(1,1) > fy(1,2)) THEN
    iorder_sn = -1
  END IF
  IF(detailout) THEN  
    WRITE(6,'(3X,A,I5)') 'X Order (WE) :',iorder_we 
    WRITE(6,'(3X,A,I5)') 'Y Order (SN) :',iorder_sn 

  END IF
   
  ratio=UNDEF
  dist_min_x=0
  dist_min_y=0
  nearestn=0
    ! ================================================================
    !   Nearest 4 Grid Points Interpolation
    ! ================================================================   
      ! ------------------------------------------------------------
      !    Search 4-Grid Points
      ! ------------------------------------------------------------      
      dist(1:num_grid_ave) = 1.D+10
      DO jy=1,ny-1
        DO ix=1,nx-1
          rxmax = MAXVAL(fx(ix:ix+1, jy:jy+1))
          rxmin = MINVAL(fx(ix:ix+1, jy:jy+1))
          rymax = MAXVAL(fy(ix:ix+1, jy:jy+1))
          rymin = MINVAL(fy(ix:ix+1, jy:jy+1))
         IF(rxmin <= datax .AND. rxmax >= datax .AND. &
           & rymin <= datay .AND. rymax >= datay ) THEN
          tmp_dist(1)=( fx(ix,jy) - datax )** order + ( fy(ix,jy) - datay )** order
          tmp_dist(2)=( fx(ix+1,jy) - datax )** order + ( fy(ix+1,jy) - datay )** order
          tmp_dist(3)=( fx(ix+1,jy+1) - datax )** order + ( fy(ix+1,jy+1) - datay )** order
          tmp_dist(4)=( fx(ix,jy+1) - datax )** order + ( fy(ix,jy+1) - datay )** order

   
          IF( maxval(tmp_dist) <= maxval(dist) )THEN
            nearestn=minloc(tmp_dist)
            dist=tmp_dist
            dist_min_x(1)=ix
            dist_min_x(2)=ix+1
            dist_min_x(3)=ix+1
            dist_min_x(4)=ix
            dist_min_y(1)=jy
            dist_min_y(2)=jy
            dist_min_y(3)=jy+1
            dist_min_y(4)=jy+1
          ENDIF 
         ENDIF

        END DO
      END DO

      IF( dist_min_x(1) > 0)THEN
      sum_dist = dist(1) + dist(2) + dist(3) + dist(4)
      ratio(1) = dist(1)/sum_dist
      ratio(2) = dist(2)/sum_dist
      ratio(3) = dist(3)/sum_dist
      ratio(4) = dist(4)/sum_dist
      ENDIF
      !IF(detailout) WRITE(6,'(2X,A,5F15.5)') 'ratio      :',ratio(1:4),SUM(ratio(1:4))

        

  RETURN
END SUBROUTINE com_xy2ij

SUBROUTINE GET_WEIGHT(PARNAME,WW,WSUM,X,PRIOR)
!Based on the values of the parameter X and the conditional parameter pdf we will compute the conditional probability of being clutter
!or weather echo. 
!The computation will be perfomred one parameter at a time.
REAL(r_size), INTENT(INOUT) :: WW(radar1%na,radar1%nr,radar1%ne)
REAL(r_size), INTENT(IN)    :: X(radar1%na,radar1%nr,radar1%ne)
REAL(r_size), INTENT(INOUT) :: PRIOR(radar1%na,radar1%nr,radar1%ne)  !For Fuzzy logic option only.
REAL(r_size), INTENT(INOUT) :: WSUM(radar1%na,radar1%nr,radar1%ne)   !For Fuzzy logic option only.
CHARACTER(*), INTENT(IN)    :: PARNAME
REAL(r_size)                :: TMP, MAX_X_HIST , MIN_X_HIST , DELTA_X_HIST ,TMP_WC , TMP_WW
REAL(r_size),ALLOCATABLE    :: Y_HIST_CLUTTER(:) , Y_HIST_WEATHER(:)
INTEGER                     :: NBIN_HIST , HIST_INDEX
CHARACTER(200)              :: READFILE
INTEGER                     :: ia,ir,ie
REAL(r_size) , PARAMETER    :: WMAX=1.0d0-1.0d-3
REAL(r_size) , PARAMETER    :: WMIN=1.0d-3
REAL(r_size) , PARAMETER    :: HISTMIN=1.0d-7
REAL(r_size)                :: PARAMETER_WEIGHT

!FIRST: READ HISTOGRAM FOR CLUTTER CASES AND WEATHER ECHO CASES
 READFILE=PARNAME//'pdf_clutter.txt'
 OPEN(UNIT=30,FILE=READFILE,FORM='FORMATTED',STATUS='UNKNOWN',RECL=500)
 READ(30,*)TMP,TMP,TMP,TMP,TMP
 READ(30,*)MAX_X_HIST,MIN_X_HIST,DELTA_X_HIST,NBIN_HIST
 ALLOCATE( Y_HIST_CLUTTER( NBIN_HIST ) )
 READ(30,*)Y_HIST_CLUTTER
 CLOSE(30)

 READFILE=PARNAME//'pdf_weather.txt'
 OPEN(UNIT=30,FILE=READFILE,FORM='FORMATTED',STATUS='UNKNOWN',RECL=500)
 READ(30,*)TMP,TMP,TMP,TMP,TMP
 READ(30,*)MAX_X_HIST,MIN_X_HIST,DELTA_X_HIST,NBIN_HIST
 ALLOCATE( Y_HIST_WEATHER( NBIN_HIST ) )
 READ(30,*)Y_HIST_WEATHER
 CLOSE(30)


 !To avoid the problem of 0 probability in Bayesian classification assign a very small value.
 WHERE(Y_HIST_WEATHER < HISTMIN)Y_HIST_WEATHER=HISTMIN
 WHERE(Y_HIST_CLUTTER < HISTMIN)Y_HIST_CLUTTER=HISTMIN

!SECOND: WEIGHT ARE UPDATED BASED ON THE PARAMETER VALUE AND THE HISTOGRAMS.

IF(WEIGHT_TYPE == 1)THEN !NAIVE BAYESIAN CLASSIFIER
!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ia,ir,ie,HIST_INDEX,TMP_WC)
  DO ia=1,radar1%na
    DO ir=1,radar1%nr
      DO ie=1,radar1%ne
          IF( X(ia,ir,ie) == UNDEF )CYCLE
            HIST_INDEX=INT(FLOOR( ( X(ia,ir,ie) - MIN_X_HIST )/DELTA_X_HIST ) + 2.0 )  !Find the corresponding bin.
             IF(HIST_INDEX < 1)HIST_INDEX=1
             IF(HIST_INDEX > NBIN_HIST)HIST_INDEX=NBIN_HIST
               TMP_WC=1.0d0-WW(ia,ir,ie) !Clutter probability.

               WW(ia,ir,ie)=WW(ia,ir,ie) * Y_HIST_WEATHER(HIST_INDEX)  !Update weather probability.
               TMP_WC=TMP_WC*Y_HIST_CLUTTER(HIST_INDEX)                !Update clutter probability.

               WW(ia,ir,ie)=WW(ia,ir,ie)/(WW(ia,ir,ie)+TMP_WC)  !Normalize weather probability (clutter probability will be 1-WW so there is no
                                                                      !need to store it.

         !Prevent the weigths from becoming to big or to small.
         IF( WW(ia,ir,ie) > WMAX)WW(ia,ir,ie)=WMAX
         IF( WW(ia,ir,ie) < WMIN)WW(ia,ir,ie)=WMIN

      ENDDO
    ENDDO
  ENDDO
!$OMP END PARALLEL DO

ENDIF !END OF NAIVE BAYESIAN CLASSIFIER
! WRITE(6,*)maxval(WW),minval(WW),WW(61,218,1),X(61,218,1)

IF(WEIGHT_TYPE == 2 )THEN !FUZZY LOGIC CLASSIFIER BASED ON OBJECTIVE FUNCTIONS

!Compute the classification index, that will be used as relative weights for the different parameters.
CALL COMPUTE_CLASSIFICATION_INDEX(Y_HIST_CLUTTER,Y_HIST_WEATHER,NBIN_HIST,PARAMETER_WEIGHT)
WRITE(*,*)"CLASSIFICATION INDEX FOR PARAMETER ", PARNAME ," IS ",PARAMETER_WEIGHT
!$OMP PARALLEL DO SCHEDULE(DYNAMIC) PRIVATE(ia,ir,ie,HIST_INDEX,TMP_WC)
  DO ia=1,radar1%na
    DO ir=1,radar1%nr
      DO ie=1,radar1%ne
             IF( X(ia,ir,ie) == UNDEF )CYCLE
             HIST_INDEX=INT(FLOOR( ( X(ia,ir,ie) - MIN_X_HIST )/DELTA_X_HIST ) + 2.0 )  !Find the corresponding bin.
             IF(HIST_INDEX < 1)HIST_INDEX=1
             IF(HIST_INDEX > NBIN_HIST)HIST_INDEX=NBIN_HIST

             TMP_WW=PRIOR(ia,ir,ie)*Y_HIST_WEATHER(HIST_INDEX)  !Compute weather probability associated with this parameter
             TMP_WC=(1-PRIOR(ia,ir,ie))*Y_HIST_CLUTTER(HIST_INDEX)    !Compute clutter probability associated with this parameter

             TMP_WW=TMP_WW/(TMP_WW+TMP_WC)

             WSUM(ia,ir,ie)=WSUM(ia,ir,ie)+PARAMETER_WEIGHT
             WW(ia,ir,ie)=WW(ia,ir,ie)+PARAMETER_WEIGHT*TMP_WW
      ENDDO
    ENDDO
  ENDDO
!$OMP END PARALLEL DO


ENDIF !END OF FUZZY LOGIC CLASSIFIER

 DEALLOCATE(Y_HIST_CLUTTER,Y_HIST_WEATHER)


RETURN
END SUBROUTINE GET_WEIGHT

SUBROUTINE COMPUTE_CLASSIFICATION_INDEX(PDF1,PDF2,NBIN,CLASSIFICATION_INDEX)
INTEGER, INTENT(IN) :: NBIN
REAL(r_size), INTENT(IN) :: PDF1(NBIN) , PDF2(NBIN)
REAL(r_size), INTENT(OUT):: CLASSIFICATION_INDEX
REAL(r_size) :: P1(NBIN) , AUX1,AUX2
INTEGER      :: i

AUX1=0.0d0
AUX2=0.0d0

DO  i=1,NBIN

  IF( PDF1(i) + PDF2(i) > 0.0d0 )THEN
   P1(i)=PDF1(i)/(PDF1(i)+PDF2(i))
  ELSE
   P1(i)=0.0d0
  ENDIF

AUX1=AUX1 + ( PDF1(i) + PDF2(i) )*( ( P1(i) - 0.5 )**2 )

AUX2=AUX2 + ( PDF1(i) + PDF2(i) )

ENDDO

CLASSIFICATION_INDEX=AUX1/(0.25*AUX2)

END SUBROUTINE COMPUTE_CLASSIFICATION_INDEX

END MODULE COMMON_QC_TOOLS

