# MAC_MPP_Viewer
Solution for reading and viewing M365 Microsoft Project files on a Mac

===
1.  Download ProjectLibre from https://projectlibre.com
2.  make sure you have homebrew installed.
3.  run:   <code>brew install openjdk</code>
4.  download install-mpxj.sh from this repo
5.  <code>chmod +x install-mpxj.sh</code>
6.  run the <code>./install-mpxj.sh</code> script found here, to install the conversion library.
7.  To test, run the script created in the above step: <code>./mpxj-convert.sh input.mpp output.xml</code>
8.  Open output.xml in ProjectLibre
9.  download ./mpp-to-projectlibre.sh from this repo
10.  <code>chmod +x ./mpp-to-projectlibre.sh </code>
11.  Use ./mpp-to-projectlibre.sh to convert and launch projectlibre app all in one command.

   
<h1>Usage:</h1> 
<code>./mpp-to-projectlibre.sh <i>project-file.mpp</i></code>
e.g. <code>./mpp-to-projectlibre.sh ~/plans/programme.mpp</code>

Three design decisions in ./mpp-to-projectlibre.sh:

1.  Temp file naming: I used mktemp's template form (mpxj-name.XXXXXXXX.xml) rather than appending .xml to a separately-generated mktemp path — the latter is a common bug, since it produces a filename mktemp never actually created atomically, reintroducing the race condition mktemp exists to prevent.
2.  No auto-delete: open -a hands off to ProjectLibre and returns immediately — the script has no way to know when (or if) ProjectLibre has finished reading the file, so deleting it on a timer would be a guess, not a guarantee. It's left under $TMPDIR, which macOS clears on its own; delete it manually if you want it gone immediately.

3.  It defaults to ~/dev/mpxj/mpxj-convert.sh (from the install script) and app name ProjectLibre — override with MPXJ_CONVERTER / PROJECTLIBRE_APP env vars if either differs on your machine.
   

