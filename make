unset exit

if {#} == 0
   Newer obj/nl.a nl.asm nl.macros
   if {Status} != 0
      set exit on
      echo assemble +e +t nl.asm
      assemble +e +t nl.asm
      unset exit
   end

   Newer obj/objects.a objects.asm objects.macros
   if {Status} != 0
      set exit on
      echo assemble +e +t objects.asm
      assemble +e +t objects.asm
      unset exit
   end
   
else
   set exit on
   for i
      assemble +e +t {i}.asm
   end
end

echo delete paslib
delete paslib

set list        nl.a objects.a
for i in {list}
   purge >.null
   echo makelib paslib +obj/{i}
   makelib paslib +obj/{i}
end

echo copy -c paslib 13/PasLib
copy -c paslib 13/PasLib
