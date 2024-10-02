_:

{
  programs.nixvim = {
    extraConfigLua = ''
      local function vmap(keys, fn, desc)
        vim.keymap.set('v', keys, fn, { desc = desc, noremap = true })
      end
      vmap('<LeftRelease>', '"*ygv', 'yank on mouse selection')
    '';
  };
}
