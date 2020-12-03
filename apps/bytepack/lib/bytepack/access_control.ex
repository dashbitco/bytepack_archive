defmodule Bytepack.AccessControl do
  def can?([:org, :new], nil), do: true
  def can?([:org, _], %{}), do: true
  def can?([:team, _], %{}), do: true
  def can?([:purchase, _], %{}), do: true
  def can?([:sale, _], membership), do: membership.org.is_seller
  def can?([:product, _], membership), do: membership.org.is_seller
  def can?([:package, _], membership), do: membership.org.is_seller
end
