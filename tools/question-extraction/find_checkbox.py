from PIL import Image
from pathlib import Path

def checkbox_boxes(path,pdfwidth=612):
 im=Image.open(path).convert('L');s=im.width/pdfwidth
 left,right=int(34*s),int(85*s);strip=im.crop((left,0,right,im.height));px=strip.load();seen=set();out=[]
 for y in range(strip.height):
  for x in range(strip.width):
   if (x,y) in seen or px[x,y]>245:continue
   stack=[(x,y)];seen.add((x,y));component=[]
   while stack:
    a,b=stack.pop();component.append((a,b))
    for c,d in ((a-1,b),(a+1,b),(a,b-1),(a,b+1)):
     if 0<=c<strip.width and 0<=d<strip.height and (c,d) not in seen and px[c,d]<245:seen.add((c,d));stack.append((c,d))
   x0=min(p[0] for p in component);x1=max(p[0] for p in component);y0=min(p[1] for p in component);y1=max(p[1] for p in component);w=x1-x0+1;h=y1-y0+1
   if 5*s<w<13*s and .80<w/h<1.2:
    cx=(x0+x1)//2;cy=(y0+y1)//2
    if px[cx,cy]>230 and max(sum(px[xx,yy]<245 for xx in range(x0,x1+1)) for yy in range(y0,min(y0+3,y1+1)))>=.64*w and max(sum(px[xx,yy]<245 for xx in range(x0,x1+1)) for yy in range(max(y0,y1-2),y1+1))>=.64*w and all(any(px[a,b]<245 for a,b in coords) for coords in [[(cx,yy) for yy in range(y0,min(y0+5,y1+1))],[(cx,yy) for yy in range(max(y0,y1-4),y1+1)],[(xx,cy) for xx in range(x0,min(x0+5,x1+1))],[(xx,cy) for xx in range(max(x0,x1-4),x1+1)]]):out.append([(x0+left)/s,y0/s,(x1+left)/s,y1/s])
 return out
if __name__=='__main__':
 import sys
 print(checkbox_boxes(sys.argv[1]))
