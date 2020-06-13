module Spree::Api::V1::ShipmentsControllerDecorator
  def ship_for_pickup
    find_and_update_shipment
    @shipment.ship_for_pickup! if (@shipment.pickup? && (@shipment.ready? || @shipment.canceled?))
    respond_with(@shipment, default_template: :show)
  end

  def ready_for_pickup
    find_and_update_shipment
    @shipment.ready_for_pickup! if (@shipment.shipped_for_pickup? || (@shipment.pickup? && (@shipment.ready? || @shipment.canceled?)))
    respond_with(@shipment, default_template: :show)
  end

  def deliver
    find_and_update_shipment
    @shipment.deliver! if(@shipment.ready_for_pickup? || @shipment.shipped?)
    respond_with(@shipment, default_template: :show)
  end

end

Spree::Api::V1::ShipmentsController.prepend Spree::Api::V1::ShipmentsControllerDecorator
