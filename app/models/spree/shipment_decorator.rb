Spree::Shipment::FINALIZED_STATES = ['delivered', 'shipped', 'ready_for_pickup', 'shipped_for_pickup']
Spree::Shipment.class_eval do

  scope :delivered, -> { with_state('delivered') }
  scope :shipped_for_pickup, -> { with_state('shipped_for_pickup') }
  scope :ready_for_pickup, -> { with_state('ready_for_pickup') }

  state_machine do

    event :ship_for_pickup do
      transition from: [:ready, :canceled], to: :shipped_for_pickup, if: :pickup?
    end
    after_transition to: :shipped_for_pickup, do: :after_ship_for_pickup

    event :ready_for_pickup do
      transition from: [:ready, :canceled], to: :ready_for_pickup
      transition from: :shipped_for_pickup, to: :ready_for_pickup
    end
    after_transition from: [:ready, :canceled], to: :ready_for_pickup, do: :after_instant_ready_for_pickup
    after_transition from: :shipped_for_pickup, to: :ready_for_pickup, do: :after_ready_for_pickup

    event :deliver do
      transition from: [:ready_for_pickup, :shipped], to: :delivered
    end

    after_transition from: :canceled, to: [:ready_for_pickup, :shipped_for_pickup], do: :after_resume
    after_transition to: :delivered, do: :after_delivered

  end

  def finalized?
    self.class::FINALIZED_STATES.include?(state)
  end

  def determine_state(order)
    return 'canceled' if order.canceled?
    return 'pending' unless order.can_ship?
    return 'pending' if inventory_units.any? &:backordered?
    return 'shipped' if shipped?
    return 'shipped_for_pickup' if shipped_for_pickup?
    return 'ready_for_pickup' if ready_for_pickup?
    return 'delivered' if delivered?
    order.paid? || Spree::Config[:auto_capture_on_dispatch] ? 'ready' : 'pending'
  end

  def selected_shipping_rate_id=(id)
    shipping_rates.update_all(selected: false)
    shipping_rates.update(id, selected: true)
    if selected_shipping_rate.shipping_method_pickupable?
      self.address_id = selected_shipping_rate.pickup_location_address.id
      self.pickup = true
    else
      self.address_id = order.ship_address_id if order
      self.pickup = false
    end
    save!
  end

  private

  def after_ship_for_pickup
    after_ship
  end

  def after_ready_for_pickup
    Spree::ShipmentHandler.factory(self).ready_for_pickup
  end

  def after_instant_ready_for_pickup
    Spree::ShipmentHandler.factory(self).ready_for_pickup(instant: true)
  end

  def after_delivered
    Spree::ShipmentHandler.factory(self).delivered
  end

end
