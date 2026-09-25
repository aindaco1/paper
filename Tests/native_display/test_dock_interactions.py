import unittest
from unittest.mock import patch

from dock_interactions import observe


class InteractionOracleTests(unittest.TestCase):
    def test_restoration_cannot_hide_an_intermediate_disappearance(self):
        screen = dict(id='display', name='fixture', x=0, y=0, width=1280, height=720)
        window = dict(layer=1000, alpha=0.19, frame=dict(X=0, Y=0, Width=1280, Height=720))
        visible = dict(windows=[window], frontPID=7)
        hidden = dict(windows=[], frontPID=7)
        with patch('dock_interactions.time.monotonic', side_effect=[0, 0, 0.1, 0.2, 1]), \
             patch('dock_interactions.time.sleep'), patch('dock_interactions.PaperCase') as case:
            case.snapshot.side_effect = [visible, hidden, visible]
            result = observe(case, [screen], 7, 'switcher')
        self.assertEqual(result['samples'], 3)
        self.assertEqual(result['status'], 'failed')
        self.assertEqual(result['windowState'], hidden)

    def test_uninterrupted_overlay_passes(self):
        screen = dict(id='display', name='fixture', x=0, y=0, width=1280, height=720)
        window = dict(layer=1000, alpha=0.19, frame=dict(X=0, Y=0, Width=1280, Height=720))
        with patch('dock_interactions.time.monotonic', side_effect=[0, 0, 0.1, 1]), \
             patch('dock_interactions.time.sleep'), patch('dock_interactions.PaperCase') as case:
            case.snapshot.return_value = dict(windows=[window], frontPID=7)
            result = observe(case, [screen], 7, 'dock')
        self.assertEqual(result['samples'], 2)
        self.assertEqual(result['status'], 'passed')
