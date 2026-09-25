import unittest
from regression import overlay_failures

class OverlayOracleTests(unittest.TestCase):
    def test_wrong_bounds_focus_and_intensity_cannot_pass(self):
        screen=dict(name='fixture',x=-1280,y=0,width=1280,height=720)
        window=dict(layer=1000,alpha=0.19,frame=dict(X=-1280,Y=0,Width=1280,Height=720))
        self.assertEqual(overlay_failures(dict(windows=[window],frontPID=7),[screen],7),[])
        for key,value in [('Width',1000),('X',0),('Height',680)]:
            changed=dict(window,frame=dict(window['frame'],**{key:value}))
            self.assertTrue(overlay_failures(dict(windows=[changed],frontPID=7),[screen],7))
        self.assertTrue(overlay_failures(dict(windows=[window],frontPID=8),[screen],7))
        self.assertTrue(overlay_failures(dict(windows=[window],frontPID=7),[screen],7,level=26))
        self.assertEqual(overlay_failures(dict(windows=[dict(window,layer=26)],frontPID=7),[screen],7,level=26),[])
        self.assertTrue(overlay_failures(dict(windows=[dict(window,alpha=0.34)],frontPID=7),[screen],7))

    def test_off_exclusions_and_duplicate_overlays_are_observed(self):
        screen=dict(name='fixture',x=0,y=0,width=1280,height=720)
        window=dict(layer=1000,alpha=0.19,frame=dict(X=0,Y=0,Width=1280,Height=720))
        self.assertEqual(overlay_failures(dict(windows=[],frontPID=7),[],7),[])
        self.assertTrue(overlay_failures(dict(windows=[window],frontPID=7),[],7))
        self.assertTrue(overlay_failures(dict(windows=[window,window],frontPID=7),[screen],7))

if __name__ == '__main__': unittest.main()
