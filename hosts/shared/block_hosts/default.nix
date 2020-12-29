{ config, pkgs, lib, ... }:
{
  networking.extraHosts = lib.readFile ./hosts;
}
