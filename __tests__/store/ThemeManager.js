import ThemeManager from '../../assets/store/ThemeManager';

test('nColumns', () => {
  const themeManager = new ThemeManager();

  expect(themeManager.calculateColumns(1).nColumns).toBe(1);
  expect(themeManager.calculateColumns(401).nColumns).toBe(1);
  expect(themeManager.calculateColumns(801).nColumns).toBe(2);
  expect(themeManager.calculateColumns(1201).nColumns).toBe(3);
  expect(themeManager.calculateColumns(4000).nColumns).toBe(3);
});
