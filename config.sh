

SPTK=/usr/local/SPTK-3.8/bin
MGCVocoder=bin/MGCVocoder

#analysis conditions
SAMPFREQ=16000   # Sampling frequency (48kHz)
FRAMELEN=`echo $SAMPFREQ*0.025|bc`   # Frame length in point (1200 = 48000 * 0.025)
FRAMESHIFT=`echo $SAMPFREQ*0.005|bc` # Frame shift in point (240 = 48000 * 0.005)
WINDOWTYPE=1 # Window type -> 0: Blackman 1: Hamming 2: Hanning
NORMALIZE=1  # Normalization -> 0: none  1: by power  2: by magnitude
FFTLEN=1024     # FFT length in point
ALPHA=0.42   # frequency warping factor
GAMMA=1      # pole/zero weight for mel-generalized cepstral (MGC) analysis
MGCORDER=24   # order of MGC analysis
BAPORDER=24   # order of BAP analysis
LNGAIN=1     # use logarithmic gain rather than linear gain
LOWERF0=80    # lower limit for f0 extraction (Hz)
UPPERF0=1280    # upper limit for f0 extraction (Hz)

#vc
SRC=huo #source speaker
TRG=lee #target speaker
